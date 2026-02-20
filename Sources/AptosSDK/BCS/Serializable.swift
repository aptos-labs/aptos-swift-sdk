import Foundation

/// All BCS-serializable types conform to this protocol.
public protocol Serializable {
    func serialize(to serializer: inout Serializer)
}

extension Serializable {
    /// Serialize to raw bytes.
    public func bcsToBytes() -> Data {
        var serializer = Serializer()
        serialize(to: &serializer)
        return serializer.output()
    }

    /// Serialize to Hex.
    public func bcsToHex() -> Hex {
        Hex(data: bcsToBytes())
    }
}

/// All BCS-deserializable types conform to this protocol.
public protocol Deserializable {
    static func deserialize(from deserializer: inout Deserializer) throws -> Self
}
