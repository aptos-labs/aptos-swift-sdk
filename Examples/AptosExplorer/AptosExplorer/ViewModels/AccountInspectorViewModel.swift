import Foundation
import AptosSDK

@Observable @MainActor
final class AccountInspectorViewModel {
    var addressInput = ""
    var accountData: AccountData?
    var balance: UInt64?
    var resources: [AccountResource] = []
    var modules: [MoveModule] = []
    var isLoading = false
    var errorMessage: String?

    func lookup(client: AptosClient) async {
        let trimmed = addressInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let address = try AccountAddress.from(trimmed)
            async let acct = client.account.getAccount(address)
            async let bal = client.coin.getBalance(address)
            async let res = client.account.getAccountResources(address)
            async let mods = client.account.getAccountModules(address)

            let (acctResult, balResult, resResult, modsResult) = try await (acct, bal, res, mods)
            accountData = acctResult
            balance = balResult
            resources = resResult
            modules = modsResult
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        accountData = nil
        balance = nil
        resources = []
        modules = []
        errorMessage = nil
    }
}
