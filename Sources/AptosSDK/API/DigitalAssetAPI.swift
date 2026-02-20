import Foundation

/// Digital asset (NFT) operations.
public struct DigitalAssetAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient
    private let transactionAPI: TransactionAPI

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
        self.transactionAPI = TransactionAPI(config: config, client: client)
    }

    /// Creates a new collection.
    public func createCollection(
        creator: any AptosAccount,
        name: String,
        description: String,
        uri: String,
        options: TransactionOptions = TransactionOptions()
    ) async throws -> TransactionResponse {
        var nameSerializer = Serializer()
        try nameSerializer.serializeStr(name)
        var descSerializer = Serializer()
        try descSerializer.serializeStr(description)
        var uriSerializer = Serializer()
        try uriSerializer.serializeStr(uri)

        // Maximum supply of 0 means unlimited
        var maxSupplySerializer = Serializer()
        maxSupplySerializer.serializeBool(false) // Option::None

        let payload = TransactionPayload.entryFunction(EntryFunction(
            moduleId: MoveModuleId(address: .four, name: "aptos_token"),
            functionName: "create_collection",
            typeArgs: [],
            args: [
                nameSerializer.toBytes(),
                descSerializer.toBytes(),
                uriSerializer.toBytes(),
                maxSupplySerializer.toBytes(),
            ]
        ))

        return try await transactionAPI.submitAndWait(
            sender: creator, payload: payload, options: options)
    }

    /// Mints a token in a collection.
    public func mintToken(
        creator: any AptosAccount,
        collection: String,
        name: String,
        description: String,
        uri: String,
        options: TransactionOptions = TransactionOptions()
    ) async throws -> TransactionResponse {
        var collSerializer = Serializer()
        try collSerializer.serializeStr(collection)
        var nameSerializer = Serializer()
        try nameSerializer.serializeStr(name)
        var descSerializer = Serializer()
        try descSerializer.serializeStr(description)
        var uriSerializer = Serializer()
        try uriSerializer.serializeStr(uri)

        let payload = TransactionPayload.entryFunction(EntryFunction(
            moduleId: MoveModuleId(address: .four, name: "aptos_token"),
            functionName: "mint",
            typeArgs: [],
            args: [
                collSerializer.toBytes(),
                descSerializer.toBytes(),
                nameSerializer.toBytes(),
                uriSerializer.toBytes(),
            ]
        ))

        return try await transactionAPI.submitAndWait(
            sender: creator, payload: payload, options: options)
    }
}
