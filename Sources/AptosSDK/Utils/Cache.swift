import Foundation

/// Thread-safe LRU cache with TTL, implemented as an actor.
public actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let value: Value
        let expiresAt: Date
    }

    private var storage: [Key: Entry] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int
    private let defaultTTL: TimeInterval
    private var cleanupTask: Task<Void, Never>?

    public init(maxSize: Int = defaultCacheMaxSize, defaultTTL: TimeInterval = 300) {
        self.maxSize = maxSize
        self.defaultTTL = defaultTTL
    }

    /// Start periodic cleanup of expired entries.
    public func startPeriodicCleanup() {
        cleanupTask?.cancel()
        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(cacheCleanupInterval))
                guard !Task.isCancelled else { break }
                await self?.removeExpired()
            }
        }
    }

    /// Get a cached value, returning nil if not found or expired.
    public func get(_ key: Key) -> Value? {
        guard let entry = storage[key] else { return nil }
        if Date() > entry.expiresAt {
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            return nil
        }
        // Move to end of access order (most recently used)
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        return entry.value
    }

    /// Set a cached value with optional custom TTL.
    public func set(_ key: Key, value: Value, ttl: TimeInterval? = nil) {
        let expiry = Date().addingTimeInterval(ttl ?? defaultTTL)
        storage[key] = Entry(value: value, expiresAt: expiry)
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        evictIfNeeded()
    }

    /// Remove all entries.
    public func clear() {
        storage.removeAll()
        accessOrder.removeAll()
    }

    // MARK: - Internal

    private func evictIfNeeded() {
        guard storage.count > maxSize else { return }
        let evictCount = maxSize / 10
        let keysToEvict = Array(accessOrder.prefix(evictCount))
        for key in keysToEvict {
            storage.removeValue(forKey: key)
        }
        accessOrder.removeFirst(min(evictCount, accessOrder.count))
    }

    private func removeExpired() {
        let now = Date()
        let expired = storage.filter { now > $0.value.expiresAt }.map(\.key)
        for key in expired {
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }

    deinit {
        cleanupTask?.cancel()
    }
}
