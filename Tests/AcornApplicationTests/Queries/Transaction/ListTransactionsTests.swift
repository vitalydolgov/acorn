import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ListTransactions")
struct ListTransactionsTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Commands & queries
        let commands: TransactionCommands
        let queries: TransactionQueries

        let seedAccount: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Commands & queries
            self.commands = TransactionCommands(unitOfWork: uow)
            self.queries = TransactionQueries(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account
        }
    }

    private static let today = AcornDate.today()

    @Test("returns empty when the account has no transactions")
    func empty() async throws {
        let sut = try await SUT()
        let result = try await sut.queries.list(accountID: sut.seedAccount.id)
        #expect(result.isEmpty)
    }

    @Test("returns active transactions sorted by date descending")
    func sortedByDateDescending() async throws {
        let sut = try await SUT()
        let oldest = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 1, date: Self.today.adding(days: -2))
        let newest = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 2, date: Self.today)
        let middle = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 3, date: Self.today.adding(days: -1))

        let result = try await sut.queries.list(accountID: sut.seedAccount.id)
        #expect(result.map(\.id) == [newest.id, middle.id, oldest.id])
    }

    @Test("excludes soft-deleted transactions")
    func excludesDeleted() async throws {
        let sut = try await SUT()
        let kept = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 1, date: Self.today)
        let removed = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 2, date: Self.today)
        var deleted = try await sut.transactions.fetch(id: removed.id)!
        try deleted.delete()
        try await sut.transactions.save(deleted)

        let result = try await sut.queries.list(accountID: sut.seedAccount.id)
        #expect(result.map(\.id) == [kept.id])
    }

    @Test("fails for unknown account")
    func failsForUnknownAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.list(accountID: UUID())
        }
    }
}
