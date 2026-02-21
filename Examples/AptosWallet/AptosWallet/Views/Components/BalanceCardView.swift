import SwiftUI

struct BalanceCardView: View {
    let balance: UInt64
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if isLoading {
                ProgressView()
                    .frame(height: 40)
            } else {
                Text(FormatUtils.aptDisplay(balance))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }
            Text(FormatUtils.octasToAPT(balance) + " octas")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
