import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("AdjustAccount")
struct AdjustAccountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Services
        let adjustAccount: AdjustAccount

        let seedAccount: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions, transfers: transfers)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Services
            self.adjustAccount = AdjustAccount(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.get(id: account.id)!
            self.seedAccount = account
        }
    }

    private static let today = AcornDate.today()

    @Test("creates an adjustment transaction")
    func createsAdjustment() async throws {
        let sut = try await SUT()

        let tx = try await sut.adjustAccount(accountID: sut.seedAccount.id, amount: -7, date: Self.today)

        #expect(tx.amount == -7)
        #expect(tx.kind == .adjustment)
    }

    @Test("zero amount fails with invalidArgument")
    func zeroAmountFails() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try await sut.adjustAccount(accountID: sut.seedAccount.id, amount: 0, date: Self.today)
        }
    }

    @Test("fails on a closed account")
    func failsOnClosed() async throws {
        let sut = try await SUT()
        var closed = sut.seedAccount
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.adjustAccount(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        }
    }
}
