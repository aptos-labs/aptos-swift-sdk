import Foundation

/// Staking-related API operations.
public struct StakingAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Get the number of delegators for a pool.
    public func getNumberOfDelegators(poolAddress: AccountAddress) async throws -> UInt64 {
        let query = """
        query GetNumberOfDelegators($poolAddress: String) {
            num_active_delegator_per_pool(
                where: { pool_address: { _eq: $poolAddress } }
            ) {
                num_active_delegator
            }
        }
        """
        let result: AptosResponse<IndexerDelegatorsResponse> = try await client.postIndexer(
            body: GraphQLRequest(
                query: query,
                variables: ["poolAddress": poolAddress.toString()]
            ),
            originMethod: "StakingAPI.getNumberOfDelegators"
        )
        return result.data.numActiveDelegatorPerPool.first?.numActiveDelegator ?? 0
    }

    /// Get all delegators for multiple pools.
    public func getNumberOfDelegatorsForAllPools(
        minimumLedgerVersion: UInt64? = nil
    ) async throws -> [DelegatorPoolCount] {
        let query = """
        query GetNumberOfDelegatorsForAllPools {
            num_active_delegator_per_pool {
                pool_address
                num_active_delegator
            }
        }
        """
        let result: AptosResponse<IndexerAllDelegatorsResponse> = try await client.postIndexer(
            body: GraphQLRequest(query: query),
            originMethod: "StakingAPI.getNumberOfDelegatorsForAllPools"
        )
        return result.data.numActiveDelegatorPerPool
    }

    /// Get delegated staking activities.
    public func getDelegatedStakingActivities(
        delegatorAddress: AccountAddress,
        poolAddress: AccountAddress
    ) async throws -> [DelegatedStakingActivity] {
        let query = """
        query GetDelegatedStakingActivities($delegatorAddress: String, $poolAddress: String) {
            delegated_staking_activities(
                where: {
                    delegator_address: { _eq: $delegatorAddress }
                    pool_address: { _eq: $poolAddress }
                }
            ) {
                amount
                delegator_address
                event_index
                event_type
                pool_address
                transaction_version
            }
        }
        """
        let result: AptosResponse<IndexerStakingActivitiesResponse> = try await client.postIndexer(
            body: GraphQLRequest(
                query: query,
                variables: [
                    "delegatorAddress": delegatorAddress.toString(),
                    "poolAddress": poolAddress.toString(),
                ]
            ),
            originMethod: "StakingAPI.getDelegatedStakingActivities"
        )
        return result.data.delegatedStakingActivities
    }
}

// MARK: - Indexer Response Types

struct IndexerDelegatorsResponse: Codable, Sendable {
    let numActiveDelegatorPerPool: [DelegatorPoolCount]
}

struct IndexerAllDelegatorsResponse: Codable, Sendable {
    let numActiveDelegatorPerPool: [DelegatorPoolCount]
}

struct IndexerStakingActivitiesResponse: Codable, Sendable {
    let delegatedStakingActivities: [DelegatedStakingActivity]
}

public struct DelegatorPoolCount: Codable, Sendable {
    public let poolAddress: String?
    public let numActiveDelegator: UInt64
}

public struct DelegatedStakingActivity: Codable, Sendable {
    public let amount: UInt64
    public let delegatorAddress: String
    public let eventIndex: Int
    public let eventType: String
    public let poolAddress: String
    public let transactionVersion: UInt64
}
