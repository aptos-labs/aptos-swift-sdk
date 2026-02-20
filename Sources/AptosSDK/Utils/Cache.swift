import Foundation

/// Actor-based LRU cache with time-to-live expiration.
public actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: CacheEntry] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int
    private let ttl: TimeInterval

    private struct CacheEntry {
        let value: Value
        let expiry: Date
    }

    /// Creates a new LRU cache.
    public init(maxSize: Int = 100, ttl: TimeInterval = 300) {
        self.maxSize = maxSize
        self.ttl = ttl
    }

    /// Gets a value from the cache, returning nil if expired or not found.
    public func get(_ key: Key) -> Value? {
        guard let entry = storage[key] else { return nil }
        if Date() > entry.expiry {
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            return nil
        }
        // Move to end (most recently used)
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        return entry.value
    }

    /// Sets a value in the cache.
    public func set(_ key: Key, value: Value) {
        // Evict if at capacity
        while storage.count >= maxSize, let oldest = accessOrder.first {
            storage.removeValue(forKey: oldest)
            accessOrder.removeFirst()
        }

        storage[key] = CacheEntry(value: value, expiry: Date().addingTimeInterval(ttl))
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    /// Removes a value from the cache.
    public func remove(_ key: Key) {
        storage.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    /// Clears all entries.
    public func clear() {
        storage.removeAll()
        accessOrder.removeAll()
    }
}
