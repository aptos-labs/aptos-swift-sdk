import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case ledgerInfo = "Ledger Info"
    case accountInspector = "Account Inspector"
    case transactionLookup = "Transaction Lookup"
    case blockExplorer = "Block Explorer"
    case viewFunction = "View Function"
    case networkSettings = "Network Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .ledgerInfo: return "server.rack"
        case .accountInspector: return "person.crop.circle"
        case .transactionLookup: return "arrow.left.arrow.right"
        case .blockExplorer: return "square.stack.3d.up"
        case .viewFunction: return "function"
        case .networkSettings: return "gearshape"
        }
    }
}
