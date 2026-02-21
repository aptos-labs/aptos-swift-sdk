import Foundation
import AptosSDK

@Observable @MainActor
final class WalletViewModel {
    var aptosClient = AptosClient(.devnet)
    var account: Ed25519Account?
    var mnemonic: String?
    var balance: UInt64 = 0
    var recentTransactions: [TransactionResponse] = []
    var isLoading = false
    var isSending = false
    var lastTxHash: String?
    var error: AppError?
    var showOnboarding = true

    init() {
        if let saved = KeychainService.loadMnemonic() {
            do {
                let acc = try Ed25519Account.fromMnemonic(saved)
                self.account = acc
                self.mnemonic = saved
                self.showOnboarding = false
            } catch {
                self.error = AppError(title: "Restore Failed", message: error.localizedDescription)
            }
        }
    }

    func createAccount() {
        let phrase = Mnemonic.generate()
        do {
            let acc = try Ed25519Account.fromMnemonic(phrase)
            try KeychainService.saveMnemonic(phrase)
            self.account = acc
            self.mnemonic = phrase
            self.showOnboarding = false
        } catch {
            self.error = AppError(title: "Create Failed", message: error.localizedDescription)
        }
    }

    func importAccount(_ phrase: String) {
        guard Mnemonic.validate(phrase) else {
            self.error = AppError(title: "Invalid Mnemonic", message: "The recovery phrase is not valid.")
            return
        }
        do {
            let acc = try Ed25519Account.fromMnemonic(phrase)
            try KeychainService.saveMnemonic(phrase)
            self.account = acc
            self.mnemonic = phrase
            self.showOnboarding = false
            Task { await refreshAll() }
        } catch {
            self.error = AppError(title: "Import Failed", message: error.localizedDescription)
        }
    }

    func resetAccount() {
        KeychainService.deleteMnemonic()
        account = nil
        mnemonic = nil
        balance = 0
        recentTransactions = []
        showOnboarding = true
    }

    func refreshAll() async {
        await refreshBalance()
        await loadTransactions()
    }

    func refreshBalance() async {
        guard let account else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            balance = try await aptosClient.coin.getBalance(account.accountAddress)
        } catch {
            balance = 0
        }
    }

    func fundFromFaucet() async {
        guard let account else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await aptosClient.faucet.fundAccount(account.accountAddress, amount: 100_000_000)
            try? await Task.sleep(for: .seconds(2))
            await refreshBalance()
            await loadTransactions()
        } catch {
            self.error = AppError(title: "Faucet Failed", message: error.localizedDescription)
        }
    }

    func sendAPT(to recipientHex: String, amount octas: UInt64) async {
        guard let account else { return }
        isSending = true
        lastTxHash = nil
        defer { isSending = false }
        do {
            let recipient = try AccountAddress.from(recipientHex)
            let response = try await aptosClient.coin.transferAPT(
                from: account, to: recipient, amount: octas
            )
            lastTxHash = response.hash
            await refreshBalance()
            await loadTransactions()
        } catch {
            self.error = AppError(title: "Send Failed", message: error.localizedDescription)
        }
    }

    func loadTransactions() async {
        guard let account else { return }
        do {
            recentTransactions = try await aptosClient.transaction.getAccountTransactions(
                account.accountAddress, limit: 10
            )
        } catch {
            // Silently fail — new accounts may have no transactions
        }
    }
}
