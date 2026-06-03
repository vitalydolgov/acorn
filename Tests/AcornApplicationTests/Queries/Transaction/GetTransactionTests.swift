import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("GetTransaction")
struct GetTransactionTests {
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

    @Test("returns the requested transaction")
    func returnsTransaction() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 42, date: Self.today)

        let fetched = try await sut.queries.get(transactionID: tx.id)
        #expect(fetched.id == tx.id)
        #expect(fetched.amount == 42)
    }

    @Test("fails for unknown transaction")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.get(transactionID: UUID())
        }
    }

    @Test("fails for a soft-deleted transaction")
    func failsForDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 42, date: Self.today)
        var deleted = try await sut.transactions.fetch(id: tx.id)!
        try deleted.delete()
        try await sut.transactions.save(deleted)

        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.get(transactionID: tx.id)
        }
    }
}
