import SwiftUI

struct LoadingStateView: View {
    let isLoading: Bool
    let errorMessage: String?
    let isEmpty: Bool
    let emptyText: String

    init(isLoading: Bool, errorMessage: String?, isEmpty: Bool, emptyText: String = "No data") {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.isEmpty = isEmpty
        self.emptyText = emptyText
    }

    var body: some View {
        if isLoading {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage {
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        } else if isEmpty {
            ContentUnavailableView(emptyText, systemImage: "magnifyingglass")
        }
    }
}
