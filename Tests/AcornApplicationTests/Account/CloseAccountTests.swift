import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("CloseAccount")
struct CloseAccountTests {
    private struct SUT {
        let closeAccount: CloseAccount
        let openAccount: OpenAccount
        let postTransaction: PostTransaction
        let recordTransfer: RecordTransfer
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository
        let transfers: InMemoryTransferRepository
        let today: AcornDate

        init(today: AcornDate = .today()) {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            self.accounts = accounts
            self.transactions = transactions
            self.transfers = transfers
            self.today = today
            self.openAccount = OpenAccount(accountRepository: accounts)
            self.postTransaction = PostTransaction(
                accountRepository: accounts,
                transactionRepository: transactions
            )
            self.recordTransfer = RecordTransfer(
                accountRepository: accounts,
                transferRepository: transfers
            )
            let uow = InMemoryUnitOfWork(
                accounts: accounts,
                transactions: transactions,
                transfers: transfers
            )
            self.closeAccount = CloseAccount(
                unitOfWork: uow,
                todayProvider: FixedTodayProvider(date: today)
            )
        }
    }

    @Test("zero balance closes the account and posts no adjustment")
    func zeroBalanceClosesCleanly() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")

        try await sut.closeAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isClosed)
        let txs = try await sut.transactions.forAccount(account.id)
        #expect(txs.isEmpty)
    }

    @Test("positive balance posts negative adjustment and closes")
    func positiveBalanceZeroesAndCloses() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        _ = try await sut.postTransaction(accountID: account.id, amount: 100, date: sut.today)

        try await sut.closeAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isClosed)
        let txs = try await sut.transactions.forAccount(account.id)
        let adjustments = txs.filter { $0.kind == .adjustment }
        #expect(adjustments.count == 1)
        #expect(adjustments[0].amount == -100)
        #expect(adjustments[0].date == sut.today)
        let balance = BalanceCalculator.balance(
            transactions: txs,
            transfers: [Transfer](),
            accountID: account.id
        )
        #expect(balance == 0)
    }

    @Test("negative balance posts positive adjustment and closes")
    func negativeBalanceZeroesAndCloses() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        _ = try await sut.postTransaction(accountID: account.id, amount: -40, date: sut.today)

        try await sut.closeAccount(accountID: account.id)

        let txs = try await sut.transactions.forAccount(account.id)
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

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isClosed)
        let txs = try await sut.transactions.forAccount(account.id)
        let adjustments = txs.filter { $0.kind == .adjustment }
        #expect(adjustments.count == 1)
        #expect(adjustments[0].amount == -30)
    }

    @Test("ignores soft-deleted transactions when computing balance")
    func softDeletedTransactionsIgnored() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        let tx = try await sut.postTransaction(accountID: account.id, amount: 50, date: sut.today)
        var deleted = tx
        try deleted.delete()
        try await sut.transactions.save(deleted)

        try await sut.closeAccount(accountID: account.id)

        let txs = try await sut.transactions.forAccount(account.id)
        #expect(txs.contains { $0.kind == .adjustment } == false)
        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isClosed)
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.notFound) {
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
        _ = try await sut.postTransaction(accountID: account.id, amount: 100, date: sut.today)
        sut.accounts.failNextSave = true

        await #expect(throws: InjectedFailure.self) {
            try await sut.closeAccount(accountID: account.id)
        }

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isClosed == false)
        let txs = try await sut.transactions.forAccount(account.id)
        #expect(txs.contains { $0.kind == .adjustment } == false)
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        var deleted = account
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.closeAccount(accountID: account.id)
        }
    }
}
