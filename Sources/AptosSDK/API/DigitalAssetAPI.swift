import Foundation

/// Digital asset (NFT) API operations.
public struct DigitalAssetAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    // MARK: - Collection Operations

    /// Build a transaction to create a new collection.
    public func createCollectionTransaction(
        creator: AccountAddress,
        description: String,
        name: String,
        uri: String,
        maxSupply: UInt64? = nil,
        royaltyNumerator: UInt64? = nil,
        royaltyDenominator: UInt64? = nil,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let functionId: String
        var args: [AnyEncodable]
        var typeArgs: [String] = []

        if let maxSupply {
            functionId = "0x4::aptos_token::create_collection"
            args = [
                AnyEncodable(description),
                AnyEncodable(maxSupply),
                AnyEncodable(name),
                AnyEncodable(uri),
                AnyEncodable(true),   // mutable_description
                AnyEncodable(true),   // mutable_royalty
                AnyEncodable(true),   // mutable_uri
                AnyEncodable(true),   // mutable_token_description
                AnyEncodable(true),   // mutable_token_name
                AnyEncodable(true),   // mutable_token_properties
                AnyEncodable(true),   // mutable_token_uri
                AnyEncodable(true),   // tokens_burnable_by_creator
                AnyEncodable(true),   // tokens_freezable_by_creator
                AnyEncodable(royaltyNumerator ?? UInt64(0)),
                AnyEncodable(royaltyDenominator ?? UInt64(1)),
            ]
        } else {
            functionId = "0x4::aptos_token::create_collection"
            args = [
                AnyEncodable(description),
                AnyEncodable(UInt64.max),
                AnyEncodable(name),
                AnyEncodable(uri),
                AnyEncodable(true),
                AnyEncodable(true),
                AnyEncodable(true),
                AnyEncodable(true),
                AnyEncodable(true),
                AnyEncodable(true),
                AnyEncodable(true),
                AnyEncodable(true),
                AnyEncodable(true),
                AnyEncodable(royaltyNumerator ?? UInt64(0)),
                AnyEncodable(royaltyDenominator ?? UInt64(1)),
            ]
        }

        let data = InputEntryFunctionData(
            function: functionId,
            functionArguments: args,
            typeArguments: typeArgs
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: creator, data: data, options: options)
    }

    // MARK: - Token Operations

    /// Build a transaction to mint a digital asset (NFT).
    public func mintDigitalAssetTransaction(
        creator: AccountAddress,
        collection: String,
        description: String,
        name: String,
        uri: String,
        propertyKeys: [String] = [],
        propertyTypes: [PropertyType] = [],
        propertyValues: [PropertyValue] = [],
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let properties = try PropertyUtils.prepareProperties(
            keys: propertyKeys,
            types: propertyTypes,
            values: propertyValues
        )

        let data = InputEntryFunctionData(
            function: "0x4::aptos_token::mint",
            functionArguments: [
                AnyEncodable(collection),
                AnyEncodable(description),
                AnyEncodable(name),
                AnyEncodable(uri),
                AnyEncodable(properties.keys),
                AnyEncodable(properties.types),
                AnyEncodable(properties.values),
            ]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: creator, data: data, options: options)
    }

    /// Build a transaction to transfer a digital asset.
    public func transferDigitalAssetTransaction(
        sender: AccountAddress,
        digitalAssetAddress: AccountAddress,
        recipient: AccountAddress,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "0x1::object::transfer",
            functionArguments: [
                AnyEncodable(digitalAssetAddress),
                AnyEncodable(recipient),
            ],
            typeArguments: ["0x4::token::Token"]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: sender, data: data, options: options)
    }

    /// Build a transaction to burn a digital asset.
    public func burnDigitalAssetTransaction(
        creator: AccountAddress,
        digitalAssetAddress: AccountAddress,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "0x4::aptos_token::burn",
            functionArguments: [
                AnyEncodable(digitalAssetAddress),
            ]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: creator, data: data, options: options)
    }

    /// Build a transaction to freeze a digital asset transfer.
    public func freezeDigitalAssetTransferTransaction(
        creator: AccountAddress,
        digitalAssetAddress: AccountAddress,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "0x4::aptos_token::freeze_transfer",
            functionArguments: [AnyEncodable(digitalAssetAddress)]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: creator, data: data, options: options)
    }

    /// Build a transaction to unfreeze a digital asset transfer.
    public func unfreezeDigitalAssetTransferTransaction(
        creator: AccountAddress,
        digitalAssetAddress: AccountAddress,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "0x4::aptos_token::unfreeze_transfer",
            functionArguments: [AnyEncodable(digitalAssetAddress)]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: creator, data: data, options: options)
    }

    // MARK: - Indexer Queries

    /// Get tokens owned by an account.
    public func getOwnedDigitalAssets(
        ownerAddress: AccountAddress,
        options: PaginationOptions? = nil
    ) async throws -> [IndexerTokenData] {
        let query = """
        query GetAccountOwnedTokens($ownerAddress: String, $limit: Int, $offset: Int) {
            current_token_ownerships_v2(
                where: { owner_address: { _eq: $ownerAddress }, amount: { _gt: 0 } }
                limit: $limit
                offset: $offset
            ) {
                token_data_id
                token_standard
                amount
                current_token_data {
                    token_name
                    token_uri
                    description
                    collection_id
                    current_collection {
                        collection_name
                        creator_address
                    }
                }
            }
        }
        """
        var variables: [String: String] = ["ownerAddress": ownerAddress.toString()]
        if let limit = options?.limit { variables["limit"] = String(limit) }
        if let offset = options?.offset { variables["offset"] = String(offset) }

        let result: AptosResponse<IndexerOwnedTokensResponse> = try await client.postIndexer(
            body: GraphQLRequest(query: query, variables: variables),
            originMethod: "DigitalAssetAPI.getOwnedDigitalAssets"
        )
        return result.data.currentTokenOwnershipsV2
    }

    /// Get collection data by creator address and name.
    public func getCollectionData(
        creatorAddress: AccountAddress,
        collectionName: String
    ) async throws -> IndexerCollectionData? {
        let query = """
        query GetCollectionData($creatorAddress: String, $collectionName: String) {
            current_collections_v2(
                where: {
                    creator_address: { _eq: $creatorAddress }
                    collection_name: { _eq: $collectionName }
                }
                limit: 1
            ) {
                collection_id
                collection_name
                creator_address
                current_supply
                max_supply
                description
                uri
            }
        }
        """
        let result: AptosResponse<IndexerCollectionsResponse> = try await client.postIndexer(
            body: GraphQLRequest(
                query: query,
                variables: [
                    "creatorAddress": creatorAddress.toString(),
                    "collectionName": collectionName,
                ]
            ),
            originMethod: "DigitalAssetAPI.getCollectionData"
        )
        return result.data.currentCollectionsV2.first
    }
}

// MARK: - Indexer Response Types

struct IndexerOwnedTokensResponse: Codable, Sendable {
    let currentTokenOwnershipsV2: [IndexerTokenData]
}

public struct IndexerTokenData: Codable, Sendable {
    public let tokenDataId: String
    public let tokenStandard: String
    public let amount: UInt64
    public let currentTokenData: IndexerCurrentTokenData?
}

public struct IndexerCurrentTokenData: Codable, Sendable {
    public let tokenName: String
    public let tokenUri: String
    public let description: String
    public let collectionId: String
    public let currentCollection: IndexerCollectionInfo?
}

public struct IndexerCollectionInfo: Codable, Sendable {
    public let collectionName: String
    public let creatorAddress: String
}

struct IndexerCollectionsResponse: Codable, Sendable {
    let currentCollectionsV2: [IndexerCollectionData]
}

public struct IndexerCollectionData: Codable, Sendable {
    public let collectionId: String
    public let collectionName: String
    public let creatorAddress: String
    public let currentSupply: UInt64
    public let maxSupply: UInt64?
    public let description: String
    public let uri: String
}
