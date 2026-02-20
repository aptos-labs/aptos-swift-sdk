import Foundation

/// Keyless authentication operations.
public struct KeylessAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Gets the pepper from the pepper service.
    public func getPepper(
        jwt: String,
        ephemeralPublicKey: Data,
        uidKey: String = "sub"
    ) async throws -> Data {
        let url = try config.getPepperURL()
        let body = PepperRequest(
            jwt: jwt,
            ephemeralPublicKey: Hex.encode(ephemeralPublicKey),
            uidKey: uidKey
        )
        let response: PepperResponse = try await client.post(
            url: url, path: "fetch", body: body, apiType: .pepper)
        return try Hex.decode(response.pepper)
    }

    /// Gets a proof from the prover service.
    public func getProof(
        jwt: String,
        ephemeralPublicKey: Data,
        pepper: Data,
        uidKey: String = "sub"
    ) async throws -> Data {
        let url = try config.getProverURL()
        let body = ProverRequest(
            jwt: jwt,
            ephemeralPublicKey: Hex.encode(ephemeralPublicKey),
            pepper: Hex.encode(pepper),
            uidKey: uidKey
        )
        let response: ProverResponse = try await client.post(
            url: url, path: "prove", body: body, apiType: .prover)
        return try Hex.decode(response.proof)
    }
}

private struct PepperRequest: Encodable {
    let jwt: String
    let ephemeralPublicKey: String
    let uidKey: String

    enum CodingKeys: String, CodingKey {
        case jwt
        case ephemeralPublicKey = "epk"
        case uidKey = "uid_key"
    }
}

private struct PepperResponse: Decodable {
    let pepper: String
}

private struct ProverRequest: Encodable {
    let jwt: String
    let ephemeralPublicKey: String
    let pepper: String
    let uidKey: String

    enum CodingKeys: String, CodingKey {
        case jwt
        case ephemeralPublicKey = "epk"
        case pepper
        case uidKey = "uid_key"
    }
}

private struct ProverResponse: Decodable {
    let proof: String
}
