import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("TransactionQueries")
struct TransactionQueriesTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Queries & commands
        let queries: TransactionQueries
        let transactionCommands: TransactionCommands
        let transferCommands: TransferCommands

        let seedAccount: Account
        let seedCounterpart: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Queries & commands
            self.queries = TransactionQueries(unitOfWork: uow)
            self.transactionCommands = TransactionCommands(unitOfWork: uow)
            self.transferCommands = TransferCommands(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account

            var counterpart = try Account.make(name: "Savings", notes: "")
            try await accounts.save(counterpart)
            counterpart = try await accounts.fetch(id: counterpart.id)!
            self.seedCounterpart = counterpart
        }

        func makeTransfer() async throws -> (from: Transaction, to: Transaction) {
            try await transferCommands.record(
                fromAccountID: seedAccount.id,
                toAccountID: seedCounterpart.id,
                amount: 50,
                date: .today()
            )
        }
    }

    private static let today = AcornDate.today()

    // MARK: - get

    @Test("returns the requested transaction")
    func getReturnsTransaction() async throws {
        let sut = try await SUT()
        let tx = try await sut.transactionCommands.record(accountID: sut.seedAccount.id, amount: 42, date: Self.today)

        let fetched = try await sut.queries.get(transactionID: tx.id)
        #expect(fetched.id == tx.id)
        #expect(fetched.amount == 42)
    }

    @Test("fails for unknown transaction")
    func getFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.get(transactionID: UUID())
        }
    }

    @Test("fails for a soft-deleted transaction")
    func getFailsForDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.transactionCommands.record(accountID: sut.seedAccount.id, amount: 42, date: Self.today)
        var deleted = try await sut.transactions.fetch(id: tx.id)!
        try deleted.delete()
        try await sut.transactions.save(deleted)

        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.get(transactionID: tx.id)
        }
    }

    // MARK: - list

    @Test("returns empty when the account has no transactions")
    func listEmpty() async throws {
        let sut = try await SUT()
        let result = try await sut.queries.list(accountID: sut.seedAccount.id)
        #expect(result.isEmpty)
    }

    @Test("returns active transactions sorted by date descending")
    func listSortedByDateDescending() async throws {
        let sut = try await SUT()
        let oldest = try await sut.transactionCommands.record(accountID: sut.seedAccount.id, amount: 1, date: Self.today.adding(days: -2))
        let newest = try await sut.transactionCommands.record(accountID: sut.seedAccount.id, amount: 2, date: Self.today)
        let middle = try await sut.transactionCommands.record(accountID: sut.seedAccount.id, amount: 3, date: Self.today.adding(days: -1))

        let result = try await sut.queries.list(accountID: sut.seedAccount.id)
        #expect(result.map(\.id) == [newest.id, middle.id, oldest.id])
    }

    @Test("excludes soft-deleted transactions")
    func listExcludesDeleted() async throws {
        let sut = try await SUT()
        let kept = try await sut.transactionCommands.record(accountID: sut.seedAccount.id, amount: 1, date: Self.today)
        let removed = try await sut.transactionCommands.record(accountID: sut.seedAccount.id, amount: 2, date: Self.today)
        var deleted = try await sut.transactions.fetch(id: removed.id)!
        try deleted.delete()
        try await sut.transactions.save(deleted)

        let result = try await sut.queries.list(accountID: sut.seedAccount.id)
        #expect(result.map(\.id) == [kept.id])
    }

    @Test("fails for unknown account")
    func listFailsForUnknownAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.list(accountID: UUID())
        }
    }

    // MARK: - listTransferLegs

    @Test("returns both legs of a transfer")
    func listTransferLegsReturnsBothLegs() async throws {
        let sut = try await SUT()
        let legs = try await sut.makeTransfer()
        let transferID = try #require(legs.from.transferID)

        let result = try await sut.queries.listTransferLegs(transferID: transferID)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.isTransferLeg })
        #expect(Set(result.map(\.id)) == [legs.from.id, legs.to.id])
        #expect(result.allSatisfy { $0.transferID == transferID })
    }

    @Test("fails for unknown transfer")
    func listTransferLegsFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.listTransferLegs(transferID: UUID())
        }
    }
}
