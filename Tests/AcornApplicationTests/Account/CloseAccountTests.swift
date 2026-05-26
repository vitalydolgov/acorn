import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

private struct InjectedFailure: Error, Equatable {}

@Suite("CloseAccount")
struct CloseAccountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork
        let todayProvider: TodayProvider

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Services
        let openAccount: OpenAccount
        let recordTransaction: RecordTransaction
        let recordTransfer: RecordTransfer
        let closeAccount: CloseAccount

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()

            self.uow = InMemoryUnitOfWork(
                accounts: accounts,
                transactions: transactions
            )
            self.todayProvider = FixedTodayProvider(date: .today())

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Services
            self.openAccount = OpenAccount(unitOfWork: uow)
            self.recordTransaction = RecordTransaction(unitOfWork: uow)
            self.recordTransfer = RecordTransfer(unitOfWork: uow)
            self.closeAccount = CloseAccount(
                unitOfWork: uow,
                todayProvider: todayProvider
            )
        }

        var today: AcornDate { todayProvider.today() }
    }

    @Test("zero balance closes the account and posts no adjustment")
    func zeroBalanceClosesCleanly() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")

        try await sut.closeAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed)
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        #expect(txs.isEmpty)
    }

    @Test("positive balance posts negative adjustment and closes")
    func positiveBalanceZeroesAndCloses() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        _ = try await sut.recordTransaction(accountID: account.id, amount: 100, date: sut.today)

        try await sut.closeAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed)
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        let adjustments = txs.filter { $0.kind == .adjustment }
        #expect(adjustments.count == 1)
        #expect(adjustments[0].amount == -100)
        #expect(adjustments[0].date == sut.today)
        let balance = BalanceCalculator.balance(
            transactions: txs,
            accountID: account.id
        )
        #expect(balance == 0)
    }

    @Test("negative balance posts positive adjustment and closes")
    func negativeBalanceZeroesAndCloses() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        _ = try await sut.recordTransaction(accountID: account.id, amount: -40, date: sut.today)

        try await sut.closeAccount(accountID: account.id)

        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        let adjustments = txs.filter { $0.kind == .adjustment }
        #expect(adjustments.count == 1)
        #expect(adjustments[0].amount == 40)
    }

    @Test("considers transfer legs when computing balance")
    func transferContributesToBalance() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        let other = try await sut.openAccount(name: "B")
        _ = try await sut.recordTransfer(
            fromAccountID: other.id,
            toAccountID: account.id,
            amount: 30,
            date: sut.today
        )

        try await sut.closeAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed)
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        let adjustments = txs.filter { $0.kind == .adjustment }
        #expect(adjustments.count == 1)
        #expect(adjustments[0].amount == -30)
    }

    @Test("ignores soft-deleted transactions when computing balance")
    func softDeletedTransactionsIgnored() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        let tx = try await sut.recordTransaction(accountID: account.id, amount: 50, date: sut.today)
        var deleted = try await sut.transactions.fetch(id: tx.id)!
        try deleted.delete()
        try await sut.transactions.save(deleted)

        try await sut.closeAccount(accountID: account.id)

        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        #expect(txs.contains { $0.kind == .adjustment } == false)
        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed)
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.closeAccount(accountID: UUID())
        }
    }

    @Test("fails when account is already closed")
    func failsWhenAlreadyClosed() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        try await sut.closeAccount(accountID: account.id)

        await #expect(throws: DomainError.invalidState("account is already closed")) {
            try await sut.closeAccount(accountID: account.id)
        }
    }

    @Test("rolls back the zeroing adjustment when the account save fails")
    func rollbackOnAccountSaveFailure() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        _ = try await sut.recordTransaction(accountID: account.id, amount: 100, date: sut.today)
        sut.accounts.saveHook = { _ in throw InjectedFailure() }

        await #expect(throws: InjectedFailure.self) {
            try await sut.closeAccount(accountID: account.id)
        }

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed == false)
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        #expect(txs.contains { $0.kind == .adjustment } == false)
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.closeAccount(accountID: account.id)
        }
    }
}
