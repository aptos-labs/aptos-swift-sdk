import Foundation

/// A Move resource value on-chain.
public struct MoveResource: Codable, Sendable {
    public let type: String
    public let data: [String: AnyCodable]
}

/// A Move value returned from a view function.
public typealias MoveValue = AnyCodable

/// An on-chain event type.
public struct EventHandle: Codable, Sendable {
    public let counter: String
    public let guid: EventHandleGUID
}

/// Event handle GUID.
public struct EventHandleGUID: Codable, Sendable {
    public let id: EventHandleId
}

/// Event handle ID components.
public struct EventHandleId: Codable, Sendable {
    public let addr: String
    public let creationNum: String
}

/// Input data for building a script transaction.
public struct InputScriptData: Sendable {
    public let bytecode: Data
    public let typeArguments: [String]
    public let functionArguments: [AnyEncodable]

    public init(
        bytecode: Data,
        typeArguments: [String] = [],
        functionArguments: [AnyEncodable] = []
    ) {
        self.bytecode = bytecode
        self.typeArguments = typeArguments
        self.functionArguments = functionArguments
    }
}

/// Input data for building a multisig transaction.
public struct InputMultisigData: Sendable {
    public let multisigAddress: AccountAddress
    public let function: String
    public let functionArguments: [AnyEncodable]
    public let typeArguments: [String]

    public init(
        multisigAddress: AccountAddress,
        function: String,
        functionArguments: [AnyEncodable] = [],
        typeArguments: [String] = []
    ) {
        self.multisigAddress = multisigAddress
        self.function = function
        self.functionArguments = functionArguments
        self.typeArguments = typeArguments
    }
}
