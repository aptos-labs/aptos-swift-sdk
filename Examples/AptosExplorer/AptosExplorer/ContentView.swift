import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @State private var selectedItem: SidebarItem? = .ledgerInfo

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
        } detail: {
            if let item = selectedItem {
                detailView(for: item)
            } else {
                ContentUnavailableView(
                    "Select an item",
                    systemImage: "sidebar.left",
                    description: Text("Choose a tool from the sidebar to get started.")
                )
            }
        }
    }

    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .ledgerInfo:
            LedgerInfoView(client: appState.aptosClient)
                .id(appState.selectedNetwork)
        case .accountInspector:
            AccountInspectorView(client: appState.aptosClient)
                .id(appState.selectedNetwork)
        case .transactionLookup:
            TransactionLookupView(client: appState.aptosClient)
                .id(appState.selectedNetwork)
        case .blockExplorer:
            BlockExplorerView(client: appState.aptosClient)
                .id(appState.selectedNetwork)
        case .viewFunction:
            ViewFunctionView(client: appState.aptosClient)
                .id(appState.selectedNetwork)
        case .networkSettings:
            NetworkSettingsView(appState: appState)
        }
    }
}
