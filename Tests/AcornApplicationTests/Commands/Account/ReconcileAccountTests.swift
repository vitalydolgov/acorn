import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ReconcileAccount")
struct ReconcileAccountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork
        let todayProvider: TodayProvider

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Commands
        let accountCommands: AccountCommands
        let transactionCommands: TransactionCommands

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            self.uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.todayProvider = FixedTodayProvider(date: .today())

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Commands
            self.accountCommands = AccountCommands(unitOfWork: uow, todayProvider: todayProvider)
            self.transactionCommands = TransactionCommands(unitOfWork: uow)
        }

        var today: AcornDate { todayProvider.today() }
    }

    @Test("promotes only cleared transactions to reconciled")
    func promotesOnlyCleared() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")

        let clearedA = try await sut.transactionCommands.record(accountID: account.id, amount: 10, date: sut.today)
        try await sut.transactionCommands.clear(transactionID: clearedA.id)
        let uncleared = try await sut.transactionCommands.record(accountID: account.id, amount: 20, date: sut.today)
        let clearedB = try await sut.transactionCommands.record(accountID: account.id, amount: 30, date: sut.today)
        try await sut.transactionCommands.clear(transactionID: clearedB.id)

        try await sut.accountCommands.reconcile(accountID: account.id)

        #expect(try #require(try await sut.transactions.fetch(id: clearedA.id)).status == .reconciled)
        #expect(try #require(try await sut.transactions.fetch(id: clearedB.id)).status == .reconciled)
        #expect(try #require(try await sut.transactions.fetch(id: uncleared.id)).status == .uncleared)
    }

    @Test("is a no-op when the account has no cleared transactions")
    func noClearedTransactions() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        let tx = try await sut.transactionCommands.record(accountID: account.id, amount: 10, date: sut.today)

        try await sut.accountCommands.reconcile(accountID: account.id)

        #expect(try #require(try await sut.transactions.fetch(id: tx.id)).status == .uncleared)
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.accountCommands.reconcile(accountID: UUID())
        }
    }

    @Test("fails on a closed account")
    func failsOnClosed() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        try await sut.accountCommands.close(accountID: account.id)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            try await sut.accountCommands.reconcile(accountID: account.id)
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.accountCommands.reconcile(accountID: account.id)
        }
    }
}
