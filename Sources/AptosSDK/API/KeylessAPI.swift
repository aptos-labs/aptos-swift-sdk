import Foundation

/// Keyless authentication API operations.
public struct KeylessAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Fetch a pepper value from the pepper service.
    public func getPepper(
        jwt: String,
        ephemeralKeyPair: EphemeralKeyPairData,
        uidKey: String = "sub",
        derivationPath: String? = nil
    ) async throws -> Data {
        var body: [String: String] = [
            "jwt_b64": jwt,
            "epk": ephemeralKeyPair.publicKeyHex,
            "exp_date_secs": String(ephemeralKeyPair.expiryDateSecs),
            "epk_blinder": ephemeralKeyPair.blinderHex,
            "uid_key": uidKey,
        ]
        if let path = derivationPath {
            body["derivation_path"] = path
        }

        let response: AptosResponse<PepperResponse> = try await client.postPepper(
            path: "/v0/signature",
            body: body,
            originMethod: "KeylessAPI.getPepper"
        )
        let pepperData = try Hex.decode(response.data.pepper)
        return pepperData
    }

    /// Fetch a zero-knowledge proof from the prover service.
    public func getProof(
        jwt: String,
        ephemeralKeyPair: EphemeralKeyPairData,
        pepper: Data,
        uidKey: String = "sub"
    ) async throws -> ZeroKnowledgeProofResponse {
        let body: [String: String] = [
            "jwt_b64": jwt,
            "epk": ephemeralKeyPair.publicKeyHex,
            "exp_date_secs": String(ephemeralKeyPair.expiryDateSecs),
            "epk_blinder": ephemeralKeyPair.blinderHex,
            "pepper": Hex.encode(pepper),
            "uid_key": uidKey,
        ]

        let response: AptosResponse<ZeroKnowledgeProofResponse> = try await client.postProver(
            path: "/v0/prove",
            body: body,
            originMethod: "KeylessAPI.getProof"
        )
        return response.data
    }
}

/// Input data for ephemeral key pair operations.
public struct EphemeralKeyPairData: Sendable {
    public let publicKeyHex: String
    public let expiryDateSecs: UInt64
    public let blinderHex: String

    public init(publicKeyHex: String, expiryDateSecs: UInt64, blinderHex: String) {
        self.publicKeyHex = publicKeyHex
        self.expiryDateSecs = expiryDateSecs
        self.blinderHex = blinderHex
    }
}

/// Response from the pepper service.
public struct PepperResponse: Codable, Sendable {
    public let pepper: String
}

/// Response from the prover service.
public struct ZeroKnowledgeProofResponse: Codable, Sendable {
    public let proof: String
}

