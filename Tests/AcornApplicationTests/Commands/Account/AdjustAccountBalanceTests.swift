import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("AdjustAccountBalance")
struct AdjustAccountBalanceTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Services
        let adjustAccountBalance: AdjustAccountBalance

        let seedAccount: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Services
            self.adjustAccountBalance = AdjustAccountBalance(
                unitOfWork: uow,
                todayProvider: FixedTodayProvider(date: .today())
            )

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account
        }
    }

    @Test("creates an adjustment transaction")
    func createsAdjustment() async throws {
        let sut = try await SUT()

        let tx = try await sut.adjustAccountBalance(accountID: sut.seedAccount.id, amount: -7)

        #expect(tx.amount == -7)
        #expect(tx.kind == .adjustment)
    }

    @Test("zero amount fails with invalidArgument")
    func zeroAmountFails() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try await sut.adjustAccountBalance(accountID: sut.seedAccount.id, amount: 0)
        }
    }

    @Test("fails on a closed account")
    func failsOnClosed() async throws {
        let sut = try await SUT()
        var closed = sut.seedAccount
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.adjustAccountBalance(accountID: sut.seedAccount.id, amount: 10)
        }
    }
}
