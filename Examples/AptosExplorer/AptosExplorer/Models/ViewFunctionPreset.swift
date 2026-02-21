import Foundation

struct ViewFunctionPreset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let function: String
    let typeArguments: [String]
    let argumentPlaceholders: [String]

    static let presets: [ViewFunctionPreset] = [
        ViewFunctionPreset(
            name: "Coin Balance",
            function: "0x1::coin::balance",
            typeArguments: ["0x1::aptos_coin::AptosCoin"],
            argumentPlaceholders: ["address"]
        ),
        ViewFunctionPreset(
            name: "Coin Supply",
            function: "0x1::coin::supply",
            typeArguments: ["0x1::aptos_coin::AptosCoin"],
            argumentPlaceholders: []
        ),
        ViewFunctionPreset(
            name: "Coin Name",
            function: "0x1::coin::name",
            typeArguments: ["0x1::aptos_coin::AptosCoin"],
            argumentPlaceholders: []
        ),
        ViewFunctionPreset(
            name: "Coin Decimals",
            function: "0x1::coin::decimals",
            typeArguments: ["0x1::aptos_coin::AptosCoin"],
            argumentPlaceholders: []
        ),
        ViewFunctionPreset(
            name: "Account Exists",
            function: "0x1::account::exists_at",
            typeArguments: [],
            argumentPlaceholders: ["address"]
        ),
    ]
}
