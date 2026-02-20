import Foundation

/// Aptos Names Service (ANS) API operations.
public struct ANSAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    /// The ANS contract address (depends on network).
    private var ansContractAddress: String {
        switch config.network {
        case .mainnet:
            return "0x867ed1f6bf916171b1de3ee92849b8978b7d1b9e0a8cc982a3d19d535dfd9c0c"
        case .testnet:
            return "0x5f8fd2347449685cf41d4db97926ec3a096eaf381332be4f1318ad4d16a8497c"
        default:
            return "0x867ed1f6bf916171b1de3ee92849b8978b7d1b9e0a8cc982a3d19d535dfd9c0c"
        }
    }

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Get the owner address for a domain name.
    public func getOwnerAddress(name: String) async throws -> AccountAddress? {
        let query = """
        query GetOwnerAddress($name: String) {
            current_aptos_names(
                where: { domain: { _eq: $name }, is_deleted: { _eq: false } }
                limit: 1
            ) {
                owner_address
            }
        }
        """
        let result: AptosResponse<IndexerNameOwnerResponse> = try await client.postIndexer(
            body: GraphQLRequest(query: query, variables: ["name": name]),
            originMethod: "ANSAPI.getOwnerAddress"
        )
        guard let ownerStr = result.data.currentAptosNames.first?.ownerAddress else {
            return nil
        }
        return try AccountAddress.fromString(ownerStr)
    }

    /// Get the target (resolved) address for a domain name.
    public func getTargetAddress(name: String) async throws -> AccountAddress? {
        let query = """
        query GetTargetAddress($name: String) {
            current_aptos_names(
                where: { domain: { _eq: $name }, is_deleted: { _eq: false } }
                limit: 1
            ) {
                registered_address
            }
        }
        """
        let result: AptosResponse<IndexerNameTargetResponse> = try await client.postIndexer(
            body: GraphQLRequest(query: query, variables: ["name": name]),
            originMethod: "ANSAPI.getTargetAddress"
        )
        guard let targetStr = result.data.currentAptosNames.first?.registeredAddress else {
            return nil
        }
        return try AccountAddress.fromString(targetStr)
    }

    /// Get the primary name for an account address.
    public func getPrimaryName(address: AccountAddress) async throws -> String? {
        let query = """
        query GetPrimaryName($address: String) {
            current_aptos_names(
                where: {
                    registered_address: { _eq: $address }
                    is_primary: { _eq: true }
                    is_deleted: { _eq: false }
                }
                limit: 1
            ) {
                domain
                subdomain
            }
        }
        """
        let result: AptosResponse<IndexerPrimaryNameResponse> = try await client.postIndexer(
            body: GraphQLRequest(
                query: query,
                variables: ["address": address.toString()]
            ),
            originMethod: "ANSAPI.getPrimaryName"
        )
        guard let name = result.data.currentAptosNames.first else {
            return nil
        }
        if let subdomain = name.subdomain, !subdomain.isEmpty {
            return "\(subdomain).\(name.domain)"
        }
        return name.domain
    }

    /// Build a transaction to register a name.
    public func registerName(
        sender: AccountAddress,
        name: String,
        expiration: ANSExpiration,
        targetAddress: AccountAddress? = nil,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "\(ansContractAddress)::domains::register_domain",
            functionArguments: [
                AnyEncodable(name),
                AnyEncodable(expiration.years),
            ]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: sender, data: data, options: options)
    }

    /// Build a transaction to set the target address for a name.
    public func setTargetAddress(
        sender: AccountAddress,
        name: String,
        address: AccountAddress,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "\(ansContractAddress)::domains::set_domain_address",
            functionArguments: [
                AnyEncodable(name),
                AnyEncodable(address),
            ]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: sender, data: data, options: options)
    }

    /// Build a transaction to set the primary name for an account.
    public func setPrimaryName(
        sender: AccountAddress,
        name: String?,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let functionId: String
        let args: [AnyEncodable]
        if let name {
            functionId = "\(ansContractAddress)::domains::set_reverse_lookup"
            args = [AnyEncodable(name)]
        } else {
            functionId = "\(ansContractAddress)::domains::clear_reverse_lookup"
            args = []
        }

        let data = InputEntryFunctionData(
            function: functionId,
            functionArguments: args
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: sender, data: data, options: options)
    }
}

/// ANS name expiration options.
public struct ANSExpiration: Sendable {
    public let years: UInt64

    public init(years: UInt64) {
        self.years = years
    }

    public static let oneYear = ANSExpiration(years: 1)
    public static let twoYears = ANSExpiration(years: 2)
}

// MARK: - Indexer Response Types

struct IndexerNameOwnerResponse: Codable, Sendable {
    let currentAptosNames: [NameOwnerEntry]
}

struct NameOwnerEntry: Codable, Sendable {
    let ownerAddress: String
}

struct IndexerNameTargetResponse: Codable, Sendable {
    let currentAptosNames: [NameTargetEntry]
}

struct NameTargetEntry: Codable, Sendable {
    let registeredAddress: String?
}

struct IndexerPrimaryNameResponse: Codable, Sendable {
    let currentAptosNames: [PrimaryNameEntry]
}

struct PrimaryNameEntry: Codable, Sendable {
    let domain: String
    let subdomain: String?
}
