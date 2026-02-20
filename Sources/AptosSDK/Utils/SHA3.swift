import Foundation

/// Minimal SHA3-256 (FIPS 202) implementation using the Keccak-f[1600] permutation.
///
/// Aptos uses SHA3-256 for authentication key derivation and transaction signing
/// message prefixes. Apple's CryptoKit only provides SHA-2, not SHA-3.
public enum SHA3 {
    /// The SHA3-256 rate in bytes (1088 bits / 8).
    private static let rate = 136
    /// Output length in bytes.
    private static let outputLength = 32

    /// Compute the SHA3-256 digest of the input data.
    public static func sha256(_ input: Data) -> Data {
        var state = [UInt64](repeating: 0, count: 25) // 5x5 lanes of 64 bits = 1600 bits
        var message = [UInt8](input)

        // Padding: append 0x06, then 0x00s, then set high bit of last byte
        let blockSize = rate
        let padLen = blockSize - (message.count % blockSize)
        if padLen == 1 {
            message.append(0x06 | 0x80)
        } else {
            message.append(0x06)
            message.append(contentsOf: [UInt8](repeating: 0, count: padLen - 2))
            message.append(0x80)
        }

        // Absorb
        for blockStart in stride(from: 0, to: message.count, by: blockSize) {
            for i in 0 ..< (blockSize / 8) {
                let offset = blockStart + i * 8
                var lane: UInt64 = 0
                for j in 0 ..< 8 {
                    lane |= UInt64(message[offset + j]) << (j * 8)
                }
                state[i] ^= lane
            }
            keccakF1600(&state)
        }

        // Squeeze (only one block needed for 256-bit output)
        var output = Data(capacity: outputLength)
        for i in 0 ..< (outputLength / 8) {
            var lane = state[i]
            for _ in 0 ..< 8 {
                output.append(UInt8(lane & 0xFF))
                lane >>= 8
            }
        }

        return output
    }

    // MARK: - Keccak-f[1600]

    private static let roundConstants: [UInt64] = [
        0x0000_0000_0000_0001, 0x0000_0000_0000_8082,
        0x8000_0000_0000_808A, 0x8000_0000_8000_8000,
        0x0000_0000_0000_808B, 0x0000_0000_8000_0001,
        0x8000_0000_8000_8081, 0x8000_0000_0000_8009,
        0x0000_0000_0000_008A, 0x0000_0000_0000_0088,
        0x0000_0000_8000_8009, 0x0000_0000_8000_000A,
        0x0000_0000_8000_808B, 0x8000_0000_0000_008B,
        0x8000_0000_0000_8089, 0x8000_0000_0000_8003,
        0x8000_0000_0000_8002, 0x8000_0000_0000_0080,
        0x0000_0000_0000_800A, 0x8000_0000_8000_000A,
        0x8000_0000_8000_8081, 0x8000_0000_0000_8080,
        0x0000_0000_8000_0001, 0x8000_0000_8000_8008,
    ]

    private static let rotationOffsets: [Int] = [
        0, 1, 62, 28, 27,
        36, 44, 6, 55, 20,
        3, 10, 43, 25, 39,
        41, 45, 15, 21, 8,
        18, 2, 61, 56, 14,
    ]

    private static let piIndices: [Int] = [
        0, 10, 20, 5, 15,
        16, 1, 11, 21, 6,
        7, 17, 2, 12, 22,
        23, 8, 18, 3, 13,
        14, 24, 9, 19, 4,
    ]

    private static func keccakF1600(_ state: inout [UInt64]) {
        var c = [UInt64](repeating: 0, count: 5)
        var d = [UInt64](repeating: 0, count: 5)
        var b = [UInt64](repeating: 0, count: 25)

        for round in 0 ..< 24 {
            // θ step
            for x in 0 ..< 5 {
                c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
            }
            for x in 0 ..< 5 {
                d[x] = c[(x + 4) % 5] ^ rotl64(c[(x + 1) % 5], 1)
            }
            for x in 0 ..< 5 {
                for y in 0 ..< 5 {
                    state[x + 5 * y] ^= d[x]
                }
            }

            // ρ and π steps
            for i in 0 ..< 25 {
                b[piIndices[i]] = rotl64(state[i], rotationOffsets[i])
            }

            // χ step
            for y in 0 ..< 5 {
                for x in 0 ..< 5 {
                    state[x + 5 * y] = b[x + 5 * y] ^ (~b[(x + 1) % 5 + 5 * y] & b[(x + 2) % 5 + 5 * y])
                }
            }

            // ι step
            state[0] ^= roundConstants[round]
        }
    }

    @inline(__always)
    private static func rotl64(_ x: UInt64, _ n: Int) -> UInt64 {
        guard n > 0 else { return x }
        return (x << n) | (x >> (64 - n))
    }
}
