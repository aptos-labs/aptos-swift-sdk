import Foundation

// MARK: - IndexerClient

/// Client for pre-built indexer (GraphQL) queries.
public struct IndexerClient: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Executes a raw GraphQL query.
    public func query<T: Decodable & Sendable>(
        _ query: String,
        variables: [String: AnyCodable] = [:]
    ) async throws -> T {
        let url = try config.getIndexerURL()
        let body = GraphQLRequest(query: query, variables: variables)
        return try await client.post(url: url, path: "", body: body, apiType: .indexer)
    }

    /// Gets tokens owned by an account.
    public func getTokensOwnedByAddress(
        _ address: AccountAddress
    ) async throws -> GraphQLResponse {
        let gql = """
        query GetTokens($address: String!) {
            current_token_ownerships_v2(
                where: { owner_address: { _eq: $address }, amount: { _gt: "0" } }
            ) {
                token_data_id
                amount
                current_token_data {
                    token_name
                    collection_id
                    token_uri
                    description
                }
            }
        }
        """
        return try await query(gql, variables: ["address": AnyCodable(address.toHex())])
    }

    /// Gets account transactions from the indexer.
    public func getAccountTransactions(
        _ address: AccountAddress,
        limit: Int = 25
    ) async throws -> GraphQLResponse {
        let gql = """
        query GetAccountTransactions($address: String!, $limit: Int!) {
            account_transactions(
                where: { account_address: { _eq: $address } }
                order_by: { transaction_version: desc }
                limit: $limit
            ) {
                transaction_version
                coin_activities {
                    activity_type
                    amount
                    coin_type
                }
            }
        }
        """
        return try await query(gql, variables: [
            "address": AnyCodable(address.toHex()),
            "limit": AnyCodable(limit),
        ])
    }
}

// MARK: - GraphQLRequest

private struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: AnyCodable]
}

// MARK: - GraphQLResponse

/// GraphQL response container.
public struct GraphQLResponse: Decodable, Sendable {
    public let data: AnyCodable?
    public let errors: [GraphQLError]?
}

// MARK: - GraphQLError

/// GraphQL error.
public struct GraphQLError: Decodable, Sendable {
    public let message: String
    public let locations: [GraphQLErrorLocation]?
    public let path: [String]?
}

// MARK: - GraphQLErrorLocation

/// GraphQL error location.
public struct GraphQLErrorLocation: Decodable, Sendable {
    public let line: Int
    public let column: Int
}
