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

    static func formatNumber(_ value: String) -> String {
        guard let num = UInt64(value) else { return value }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: num)) ?? value
    }
}
