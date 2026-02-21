import SwiftUI

struct StatusBadge: View {
    let success: Bool?

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }

    private var color: Color {
        switch success {
        case true: return .green
        case false: return .red
        default: return .orange
        }
    }

    private var text: String {
        switch success {
        case true: return "Success"
        case false: return "Failed"
        default: return "Pending"
        }
    }
}
