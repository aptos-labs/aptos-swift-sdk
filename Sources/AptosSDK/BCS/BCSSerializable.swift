import Foundation

/// A type that can be serialized to BCS format.
public protocol BCSSerializable: Sendable {
    /// Serializes this value into the given serializer.
    func serialize(to serializer: inout Serializer) throws
}

/// A type that can be deserialized from BCS format.
public protocol BCSDeserializable: Sendable {
    /// Deserializes a value from the given deserializer.
    static func deserialize(from deserializer: inout Deserializer) throws -> Self
}

/// A type that supports both BCS serialization and deserialization.
public typealias BCSCodable = BCSSerializable & BCSDeserializable

// MARK: - Top-level Helpers

/// Serializes a BCS-serializable value to bytes.
public func bcsToBytes<T: BCSSerializable>(_ value: T) throws -> Data {
    var serializer = Serializer()
    try value.serialize(to: &serializer)
    return serializer.toBytes()
}

/// Deserializes a BCS-encoded value from bytes.
public func bcsFromBytes<T: BCSDeserializable>(_ type: T.Type, _ data: Data) throws -> T {
    var deserializer = Deserializer(data: data)
    let value = try T.deserialize(from: &deserializer)
    try deserializer.assertFinished()
    return value
}

// MARK: - Standard Type Conformances

extension Bool: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeBool(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Bool {
        try deserializer.deserializeBool()
    }
}

extension UInt8: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeU8(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> UInt8 {
        try deserializer.deserializeU8()
    }
}

extension UInt16: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeU16(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> UInt16 {
        try deserializer.deserializeU16()
    }
}

extension UInt32: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeU32(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> UInt32 {
        try deserializer.deserializeU32()
    }
}

extension UInt64: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeU64(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> UInt64 {
        try deserializer.deserializeU64()
    }
}

extension Int8: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeI8(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Int8 {
        try deserializer.deserializeI8()
    }
}

extension Int16: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeI16(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Int16 {
        try deserializer.deserializeI16()
    }
}

extension Int32: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeI32(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Int32 {
        try deserializer.deserializeI32()
    }
}

extension Int64: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeI64(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Int64 {
        try deserializer.deserializeI64()
    }
}

extension String: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeStr(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> String {
        try deserializer.deserializeStr()
    }
}

extension Data: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(self)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Data {
        try deserializer.deserializeBytes()
    }
}
