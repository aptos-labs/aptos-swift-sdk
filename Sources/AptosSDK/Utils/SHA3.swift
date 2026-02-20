import Foundation

// MARK: - SHA3

/// SHA3-256 (Keccak-256 with NIST padding) implementation.
///
/// This is a minimal, dependency-free implementation of SHA3-256 used
/// for address derivation, signing messages, and authentication keys.
public enum SHA3 {
    /// Computes the SHA3-256 hash of the given data.
    public static func sha256(_ data: Data) -> Data {
        sha256(Array(data))
    }

    /// Computes the SHA3-256 hash of the given bytes.
    public static func sha256(_ bytes: [UInt8]) -> Data {
        var state = KeccakState()
        state.absorb(bytes, rate: 136) // SHA3-256 rate = 1088 bits = 136 bytes
        return state.squeeze(count: 32, rate: 136)
    }

    /// Computes a domain-separated hash: SHA3-256(SHA3-256(domain) || data).
    public static func hashWithDomain(_ domain: String, _ data: Data) -> Data {
        let domainHash = sha256(Array(domain.utf8))
        var combined = Data(domainHash)
        combined.append(data)
        return sha256(combined)
    }

    /// Computes the domain-separated signing prefix: SHA3-256(domain_string).
    public static func signingPrefix(_ domain: String) -> Data {
        sha256(Array(domain.utf8))
    }
}

// MARK: - KeccakState

/// Keccak-f[1600] permutation state for SHA3.
private struct KeccakState {
    var state: [UInt64] = Array(repeating: 0, count: 25)

    /// Round constants for Keccak-f[1600]
    static let roundConstants: [UInt64] = [
        0x0000_0000_0000_0001, 0x0000_0000_0000_8082, 0x8000_0000_0000_808A, 0x8000_0000_8000_8000,
        0x0000_0000_0000_808B, 0x0000_0000_8000_0001, 0x8000_0000_8000_8081, 0x8000_0000_0000_8009,
        0x0000_0000_0000_008A, 0x0000_0000_0000_0088, 0x0000_0000_8000_8009, 0x0000_0000_8000_000A,
        0x0000_0000_8000_808B, 0x8000_0000_0000_008B, 0x8000_0000_0000_8089, 0x8000_0000_0000_8003,
        0x8000_0000_0000_8002, 0x8000_0000_0000_0080, 0x0000_0000_0000_800A, 0x8000_0000_8000_000A,
        0x8000_0000_8000_8081, 0x8000_0000_0000_8080, 0x0000_0000_8000_0001, 0x8000_0000_8000_8008,
    ]

    /// Rotation offsets
    static let rotationOffsets: [Int] = [
        0, 1, 62, 28, 27, 36, 44, 6, 55, 20,
        3, 10, 43, 25, 39, 41, 45, 15, 21, 8,
        18, 2, 61, 56, 14,
    ]

    /// Pi permutation indices
    static let piIndices: [Int] = [
        0, 10, 20, 5, 15, 16, 1, 11, 21, 6,
        7, 17, 2, 12, 22, 23, 8, 18, 3, 13,
        14, 24, 9, 19, 4,
    ]

    mutating func absorb(_ input: [UInt8], rate: Int) {
        var offset = 0
        let blockSize = rate

        while offset < input.count {
            let blockEnd = min(offset + blockSize, input.count)
            let block = Array(input[offset ..< blockEnd])

            // XOR block into state
            for i in 0 ..< (block.count / 8) {
                let word = block.withUnsafeBufferPointer { buf -> UInt64 in
                    var value: UInt64 = 0
                    for j in 0 ..< 8 {
                        let idx = i * 8 + j
                        if idx < buf.count {
                            value |= UInt64(buf[idx]) << (j * 8)
                        }
                    }
                    return value
                }
                state[i] ^= word
            }

            // Handle remaining bytes (less than 8)
            let fullWords = block.count / 8
            let remainingStart = fullWords * 8
            if remainingStart < block.count {
                var word: UInt64 = 0
                for j in remainingStart ..< block.count {
                    word |= UInt64(block[j]) << ((j - remainingStart) * 8)
                }
                state[fullWords] ^= word
            }

            offset += blockSize

            if blockEnd - (offset - blockSize) == blockSize {
                keccakF()
            }
        }

        // Add SHA3 domain separation byte (0x06) and final bit (0x80)
        let padPosition = input.count % rate
        state[padPosition / 8] ^= UInt64(0x06) << ((padPosition % 8) * 8)
        state[(rate - 1) / 8] ^= UInt64(0x80) << (((rate - 1) % 8) * 8)
        keccakF()
    }

    mutating func squeeze(count: Int, rate: Int) -> Data {
        var output = Data(capacity: count)
        var remaining = count

        while remaining > 0 {
            let blockBytes = min(remaining, rate)
            for i in 0 ..< (blockBytes / 8) {
                var word = state[i]
                let bytesToWrite = min(8, remaining)
                for _ in 0 ..< bytesToWrite {
                    output.append(UInt8(word & 0xFF))
                    word >>= 8
                    remaining -= 1
                    if remaining == 0 { break }
                }
                if remaining == 0 { break }
            }

            // Handle remaining partial word
            if remaining > 0 {
                let fullWords = blockBytes / 8
                if fullWords < rate / 8 {
                    var word = state[fullWords]
                    let bytesToWrite = min(blockBytes - fullWords * 8, remaining)
                    for _ in 0 ..< bytesToWrite {
                        output.append(UInt8(word & 0xFF))
                        word >>= 8
                        remaining -= 1
                    }
                }
            }

            if remaining > 0 {
                keccakF()
            }
        }

        return output
    }

    mutating func keccakF() {
        for round in 0 ..< 24 {
            // θ (Theta)
            var c = [UInt64](repeating: 0, count: 5)
            for x in 0 ..< 5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }

            var d = [UInt64](repeating: 0, count: 5)
            for x in 0 ..< 5 {
                d[x] = c[(x + 4) % 5] ^ rotl64(c[(x + 1) % 5], 1)
            }

            for x in 0 ..< 5 {
                for y in 0 ..< 5 {
                    state[x + 5 * y] ^= d[x]
                }
            }

            // ρ (Rho) and π (Pi)
            var b = [UInt64](repeating: 0, count: 25)
            for i in 0 ..< 25 {
                b[Self.piIndices[i]] = rotl64(state[i], Self.rotationOffsets[i])
            }

            // χ (Chi)
            for y in 0 ..< 5 {
                for x in 0 ..< 5 {
                    state[x + 5 * y] = b[x + 5 * y] ^ (~b[(x + 1) % 5 + 5 * y] & b[(x + 2) % 5 + 5 * y])
                }
            }

            // ι (Iota)
            state[0] ^= Self.roundConstants[round]
        }
    }

    private func rotl64(_ value: UInt64, _ count: Int) -> UInt64 {
        guard count > 0 else { return value }
        return (value << count) | (value >> (64 - count))
    }
}
