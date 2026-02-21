import Foundation

/// Actor-based LRU cache with time-to-live expiration.
public actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private struct CacheEntry {
        var value: Value
        var expiry: Date
        var prev: Key?
        var next: Key?
    }

    private var storage: [Key: CacheEntry] = [:]
    private var head: Key?
    private var tail: Key?
    private let maxSize: Int
    private let ttl: TimeInterval

    /// Creates a new LRU cache.
    public init(maxSize: Int = 100, ttl: TimeInterval = 300) {
        self.maxSize = maxSize
        self.ttl = ttl
    }

    /// Gets a value from the cache, returning nil if expired or not found.
    public func get(_ key: Key) -> Value? {
        guard let entry = storage[key] else { return nil }
        if Date() > entry.expiry {
            remove(key)
            return nil
        }
        moveToTail(key)
        return storage[key]?.value
    }

    /// Sets a value in the cache.
    public func set(_ key: Key, value: Value) {
        if var existing = storage[key] {
            existing.value = value
            existing.expiry = Date().addingTimeInterval(ttl)
            storage[key] = existing
            moveToTail(key)
            return
        }

        while storage.count >= maxSize, let oldest = head {
            remove(oldest)
        }

        storage[key] = CacheEntry(
            value: value,
            expiry: Date().addingTimeInterval(ttl),
            prev: tail,
            next: nil
        )

        if let currentTail = tail {
            if var tailEntry = storage[currentTail] {
                tailEntry.next = key
                storage[currentTail] = tailEntry
            }
        } else {
            head = key
        }

        tail = key
    }

    /// Removes a value from the cache.
    public func remove(_ key: Key) {
        guard let entry = storage.removeValue(forKey: key) else { return }

        if let prev = entry.prev {
            if var prevEntry = storage[prev] {
                prevEntry.next = entry.next
                storage[prev] = prevEntry
            }
        } else {
            head = entry.next
        }

        if let next = entry.next {
            if var nextEntry = storage[next] {
                nextEntry.prev = entry.prev
                storage[next] = nextEntry
            }
        } else {
            tail = entry.prev
        }
    }

    /// Clears all entries.
    public func clear() {
        storage.removeAll()
        head = nil
        tail = nil
    }

    private func moveToTail(_ key: Key) {
        guard tail != key, var entry = storage[key] else { return }

        if let prev = entry.prev {
            if var prevEntry = storage[prev] {
                prevEntry.next = entry.next
                storage[prev] = prevEntry
            }
        } else {
            head = entry.next
        }

        if let next = entry.next {
            if var nextEntry = storage[next] {
                nextEntry.prev = entry.prev
                storage[next] = nextEntry
            }
        } else {
            tail = entry.prev
        }

        entry.prev = tail
        entry.next = nil
        storage[key] = entry

        if let currentTail = tail {
            if var tailEntry = storage[currentTail] {
                tailEntry.next = key
                storage[currentTail] = tailEntry
            }
        } else {
            head = key
        }
        tail = key
    }
}
