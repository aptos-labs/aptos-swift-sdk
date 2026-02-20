import Foundation

/// Builds raw transactions by fetching on-chain state and constructing payloads.
public struct TransactionBuilder: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    // MARK: - Build Simple Transaction

    /// Build a simple single-signer transaction.
    public func buildSimple(
        sender: AccountAddress,
        data: InputEntryFunctionData,
        options: TransactionOptions? = nil,
        withFeePayer: Bool = false
    ) async throws -> SimpleTransaction {
        let payload = try buildEntryFunctionPayload(data)
        let rawTxn = try await buildRawTransaction(
            sender: sender,
            payload: .entryFunction(payload),
            options: options
        )
        let feePayerAddress = withFeePayer ? AccountAddress.ZERO : nil
        return SimpleTransaction(rawTransaction: rawTxn, feePayerAddress: feePayerAddress)
    }

    /// Build a simple transaction with a script payload.
    public func buildSimpleScript(
        sender: AccountAddress,
        bytecode: Data,
        typeArguments: [TypeTag] = [],
        arguments: [Data] = [],
        options: TransactionOptions? = nil,
        withFeePayer: Bool = false
    ) async throws -> SimpleTransaction {
        let payload = Script(
            bytecode: bytecode,
            typeArguments: typeArguments,
            arguments: arguments
        )
        let rawTxn = try await buildRawTransaction(
            sender: sender,
            payload: .script(payload),
            options: options
        )
        let feePayerAddress = withFeePayer ? AccountAddress.ZERO : nil
        return SimpleTransaction(rawTransaction: rawTxn, feePayerAddress: feePayerAddress)
    }

    // MARK: - Build Multi-Agent Transaction

    /// Build a multi-agent transaction.
    public func buildMultiAgent(
        sender: AccountAddress,
        data: InputEntryFunctionData,
        secondarySignerAddresses: [AccountAddress],
        options: TransactionOptions? = nil,
        withFeePayer: Bool = false
    ) async throws -> MultiAgentTransaction {
        let payload = try buildEntryFunctionPayload(data)
        let rawTxn = try await buildRawTransaction(
            sender: sender,
            payload: .entryFunction(payload),
            options: options
        )
        let feePayerAddress = withFeePayer ? AccountAddress.ZERO : nil
        return MultiAgentTransaction(
            rawTransaction: rawTxn,
            secondarySignerAddresses: secondarySignerAddresses,
            feePayerAddress: feePayerAddress
        )
    }

    // MARK: - Internal Helpers

    /// Build the raw transaction by fetching chain state.
    private func buildRawTransaction(
        sender: AccountAddress,
        payload: TransactionPayload,
        options: TransactionOptions?
    ) async throws -> RawTransaction {
        async let accountInfo = fetchAccountInfo(sender, sequenceNumber: options?.accountSequenceNumber)
        async let gasPrice = fetchGasPrice(override: options?.gasUnitPrice)
        async let chainIdValue = fetchChainId()

        let (sequenceNumber, gasUnitPrice, chainId) = try await (accountInfo, gasPrice, chainIdValue)

        let maxGasAmount = options?.maxGasAmount ?? defaultMaxGasAmount
        let expirationTimestamp = options?.expireTimestamp ??
            UInt64(Date().timeIntervalSince1970) + defaultTxnExpSecFromNow

        return RawTransaction(
            sender: sender,
            sequenceNumber: sequenceNumber,
            payload: payload,
            maxGasAmount: maxGasAmount,
            gasUnitPrice: gasUnitPrice,
            expirationTimestampSecs: expirationTimestamp,
            chainId: chainId
        )
    }

    /// Build an entry function payload from input data.
    private func buildEntryFunctionPayload(_ data: InputEntryFunctionData) throws -> EntryFunction {
        let typeArgs = try data.typeArguments.map { try TypeTag.parse($0) }

        // Encode arguments based on ABI if available, otherwise treat as raw BCS data
        let encodedArgs: [Data]
        if let abi = data.abi {
            encodedArgs = try encodeArguments(data.functionArguments, parameters: abi.parameters)
        } else {
            encodedArgs = try data.functionArguments.map { arg in
                try encodeArgument(arg)
            }
        }

        return try EntryFunction.natural(
            data.function,
            typeArguments: typeArgs,
            arguments: encodedArgs
        )
    }

    /// Encode a single argument value to BCS bytes.
    private func encodeArgument(_ arg: AnyEncodable) throws -> Data {
        var serializer = Serializer()
        switch arg.value {
        case let v as Bool:
            serializer.serializeBool(v)
        case let v as UInt8:
            serializer.serializeU8(v)
        case let v as UInt16:
            serializer.serializeU16(v)
        case let v as UInt32:
            serializer.serializeU32(v)
        case let v as UInt64:
            serializer.serializeU64(v)
        case let v as String:
            // Could be an address or a string argument
            if v.hasPrefix("0x") && v.count >= 64 {
                let addr = try AccountAddress.fromString(v)
                addr.serialize(to: &serializer)
            } else {
                serializer.serializeStr(v)
            }
        case let v as AccountAddress:
            v.serialize(to: &serializer)
        case let v as Data:
            serializer.serializeBytes(v)
        case let v as Serializable:
            v.serialize(to: &serializer)
        default:
            throw AptosError.invalidArgument("Cannot encode argument of type \(type(of: arg.value))")
        }
        return serializer.output()
    }

    /// Encode arguments against known ABI parameter types.
    private func encodeArguments(_ args: [AnyEncodable], parameters: [TypeTag]) throws -> [Data] {
        guard args.count == parameters.count else {
            throw AptosError.invalidArgument(
                "Argument count (\(args.count)) does not match parameter count (\(parameters.count))"
            )
        }
        return try zip(args, parameters).map { arg, param in
            try encodeArgumentWithType(arg, type: param)
        }
    }

    /// Encode an argument with a known Move type.
    private func encodeArgumentWithType(_ arg: AnyEncodable, type: TypeTag) throws -> Data {
        var serializer = Serializer()
        switch type {
        case .bool:
            guard let v = arg.value as? Bool else {
                throw AptosError.invalidArgument("Expected Bool for type bool")
            }
            serializer.serializeBool(v)
        case .u8:
            guard let v = arg.value as? UInt8 else {
                throw AptosError.invalidArgument("Expected UInt8 for type u8")
            }
            serializer.serializeU8(v)
        case .u16:
            guard let v = arg.value as? UInt16 else {
                throw AptosError.invalidArgument("Expected UInt16 for type u16")
            }
            serializer.serializeU16(v)
        case .u32:
            guard let v = arg.value as? UInt32 else {
                throw AptosError.invalidArgument("Expected UInt32 for type u32")
            }
            serializer.serializeU32(v)
        case .u64:
            let v: UInt64
            if let u = arg.value as? UInt64 { v = u }
            else if let s = arg.value as? String, let parsed = UInt64(s) { v = parsed }
            else { throw AptosError.invalidArgument("Expected UInt64 for type u64") }
            serializer.serializeU64(v)
        case .address:
            if let addr = arg.value as? AccountAddress {
                addr.serialize(to: &serializer)
            } else if let s = arg.value as? String {
                let addr = try AccountAddress.fromString(s)
                addr.serialize(to: &serializer)
            } else {
                throw AptosError.invalidArgument("Expected AccountAddress for type address")
            }
        default:
            return try encodeArgument(arg)
        }
        return serializer.output()
    }

    // MARK: - On-Chain Fetching

    private func fetchAccountInfo(
        _ address: AccountAddress,
        sequenceNumber: UInt64?
    ) async throws -> UInt64 {
        if let seq = sequenceNumber { return seq }
        let response: AptosResponse<AccountData> = try await client.get(
            path: "/accounts/\(address)",
            originMethod: "TransactionBuilder.fetchAccountInfo"
        )
        guard let seq = UInt64(response.data.sequenceNumber) else {
            throw AptosError.internalError("Invalid sequence number: \(response.data.sequenceNumber)")
        }
        return seq
    }

    private func fetchGasPrice(override: UInt64?) async throws -> UInt64 {
        if let price = override { return price }
        let response: AptosResponse<GasEstimation> = try await client.get(
            path: "/estimate_gas_price",
            originMethod: "TransactionBuilder.fetchGasPrice"
        )
        return response.data.gasEstimate
    }

    private func fetchChainId() async throws -> ChainId {
        if let knownId = NetworkEndpoints.chainId(for: config.network) {
            return ChainId(knownId)
        }
        let response: AptosResponse<LedgerInfo> = try await client.get(
            path: "",
            originMethod: "TransactionBuilder.fetchChainId"
        )
        return ChainId(response.data.chainId)
    }
}
