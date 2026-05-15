import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("AdjustAccount")
struct AdjustAccountTests {
    private struct SUT {
        let adjustAccount: AdjustAccount
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository
        let account: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            self.accounts = accounts
            self.transactions = transactions
            self.account = account
            self.adjustAccount = AdjustAccount(
                accountRepository: accounts,
                transactionRepository: transactions
            )
        }
    }

    private static let today = AcornDate.today()

    @Test("creates an adjustment transaction")
    func createsAdjustment() async throws {
        let sut = try await SUT()

        let tx = try await sut.adjustAccount(accountID: sut.account.id, amount: -7, date: Self.today)

        #expect(tx.amount == -7)
        #expect(tx.kind == .adjustment)
    }

    @Test("zero amount fails with invalidArgument")
    func zeroAmountFails() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try await sut.adjustAccount(accountID: sut.account.id, amount: 0, date: Self.today)
        }
    }

    @Test("fails on a closed account")
    func failsOnClosed() async throws {
        let sut = try await SUT()
        var closed = sut.account
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.adjustAccount(accountID: sut.account.id, amount: 10, date: Self.today)
        }
    }
}
