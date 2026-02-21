import Foundation

enum FormatUtils {
    private static let octasPerAPT: UInt64 = 100_000_000

    static func octasToAPT(_ octas: UInt64) -> String {
        let whole = octas / octasPerAPT
        let fraction = octas % octasPerAPT
        return String(format: "%d.%08d", whole, fraction)
    }

    static func aptDisplay(_ octas: UInt64) -> String {
        let whole = octas / octasPerAPT
        let fraction = octas % octasPerAPT
        if fraction == 0 {
            return "\(whole) APT"
        }
        let trimmed = String(format: "%08d", fraction)
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        return "\(whole).\(trimmed) APT"
    }

    static func aptToOctas(_ apt: String) -> UInt64? {
        let parts = apt.split(separator: ".", maxSplits: 1)
        guard let wholePart = UInt64(parts[0]) else { return nil }
        var octas = wholePart * octasPerAPT
        if parts.count == 2 {
            let fractionStr = String(parts[1])
            guard fractionStr.count <= 8 else { return nil }
            let padded = fractionStr.padding(toLength: 8, withPad: "0", startingAt: 0)
            guard let fractionOctas = UInt64(padded) else { return nil }
            octas += fractionOctas
        }
        return octas
    }

    static func truncateAddress(_ addr: String) -> String {
        guard addr.count > 12 else { return addr }
        let prefix = addr.prefix(6)
        let suffix = addr.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    static func formatTimestamp(_ microseconds: String) -> String {
        guard let us = Double(microseconds) else { return microseconds }
        let date = Date(timeIntervalSince1970: us / 1_000_000)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
