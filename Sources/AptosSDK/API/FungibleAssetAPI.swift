import Foundation

/// Fungible asset API operations.
public struct FungibleAssetAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Get fungible asset metadata via indexer.
    public func getFungibleAssetMetadata(
        assetType: String
    ) async throws -> [FungibleAssetMetadata] {
        let query = """
        query GetFungibleAssetMetadata($assetType: String) {
            fungible_asset_metadata(
                where: { asset_type: { _eq: $assetType } }
            ) {
                asset_type
                creator_address
                decimals
                icon_uri
                name
                project_uri
                supply_aggregator_table_handle_v1
                supply_aggregator_table_key_v1
                symbol
                token_standard
            }
        }
        """
        let result: AptosResponse<IndexerFungibleAssetMetadataResponse> = try await client.postIndexer(
            body: GraphQLRequest(
                query: query,
                variables: ["assetType": assetType]
            ),
            originMethod: "FungibleAssetAPI.getFungibleAssetMetadata"
        )
        return result.data.fungibleAssetMetadata
    }

    /// Get fungible asset activities.
    public func getFungibleAssetActivities(
        assetType: String,
        options: PaginationOptions? = nil
    ) async throws -> [FungibleAssetActivity] {
        let query = """
        query GetFungibleAssetActivities($assetType: String, $limit: Int, $offset: Int) {
            fungible_asset_activities(
                where: { asset_type: { _eq: $assetType } }
                limit: $limit
                offset: $offset
            ) {
                amount
                asset_type
                entry_function_id_str
                event_index
                gas_fee_payer_address
                is_frozen
                is_gas_fee
                is_transaction_success
                owner_address
                token_standard
                transaction_timestamp
                transaction_version
                type
            }
        }
        """
        var variables: [String: String] = ["assetType": assetType]
        if let limit = options?.limit { variables["limit"] = String(limit) }
        if let offset = options?.offset { variables["offset"] = String(offset) }

        let result: AptosResponse<IndexerFungibleAssetActivitiesResponse> = try await client.postIndexer(
            body: GraphQLRequest(query: query, variables: variables),
            originMethod: "FungibleAssetAPI.getFungibleAssetActivities"
        )
        return result.data.fungibleAssetActivities
    }

    /// Build a transaction to transfer a fungible asset.
    public func transferFungibleAsset(
        sender: AccountAddress,
        fungibleAssetMetadataAddress: AccountAddress,
        recipient: AccountAddress,
        amount: UInt64,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "0x1::primary_fungible_store::transfer",
            functionArguments: [
                AnyEncodable(fungibleAssetMetadataAddress),
                AnyEncodable(recipient),
                AnyEncodable(amount),
            ],
            typeArguments: ["0x1::fungible_asset::Metadata"]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: sender, data: data, options: options)
    }

    /// Get the fungible asset balance for an account.
    public func getAccountFungibleAssetBalance(
        address: AccountAddress,
        assetType: String
    ) async throws -> UInt64 {
        let query = """
        query GetAccountFungibleAssetBalance($address: String, $assetType: String) {
            current_fungible_asset_balances(
                where: {
                    owner_address: { _eq: $address }
                    asset_type: { _eq: $assetType }
                }
                limit: 1
            ) {
                amount
            }
        }
        """
        let result: AptosResponse<IndexerFABalanceResponse> = try await client.postIndexer(
            body: GraphQLRequest(
                query: query,
                variables: [
                    "address": address.toString(),
                    "assetType": assetType,
                ]
            ),
            originMethod: "FungibleAssetAPI.getAccountFungibleAssetBalance"
        )
        return result.data.currentFungibleAssetBalances.first?.amount ?? 0
    }
}

// MARK: - Indexer Response Types

struct IndexerFungibleAssetMetadataResponse: Codable, Sendable {
    let fungibleAssetMetadata: [FungibleAssetMetadata]
}

public struct FungibleAssetMetadata: Codable, Sendable {
    public let assetType: String
    public let creatorAddress: String
    public let decimals: Int
    public let iconUri: String?
    public let name: String
    public let projectUri: String?
    public let symbol: String
    public let tokenStandard: String
}

struct IndexerFungibleAssetActivitiesResponse: Codable, Sendable {
    let fungibleAssetActivities: [FungibleAssetActivity]
}

public struct FungibleAssetActivity: Codable, Sendable {
    public let amount: UInt64?
    public let assetType: String
    public let entryFunctionIdStr: String?
    public let eventIndex: Int
    public let gasFeePayerAddress: String?
    public let isFrozen: Bool?
    public let isGasFee: Bool?
    public let isTransactionSuccess: Bool
    public let ownerAddress: String?
    public let tokenStandard: String
    public let transactionTimestamp: String
    public let transactionVersion: UInt64
    public let type: String
}

struct IndexerFABalanceResponse: Codable, Sendable {
    let currentFungibleAssetBalances: [FABalance]
}

struct FABalance: Codable, Sendable {
    let amount: UInt64
}
