import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

private struct InjectedFailure: Error, Equatable {}

@Suite("AccountCommands")
struct AccountCommandsTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork
        let todayProvider: TodayProvider

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Commands
        let accountCommands: AccountCommands
        let transactionCommands: TransactionCommands
        let transferCommands: TransferCommands

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow
            self.todayProvider = FixedTodayProvider(date: .today())

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Commands
            self.accountCommands = AccountCommands(unitOfWork: uow, todayProvider: todayProvider)
            self.transactionCommands = TransactionCommands(unitOfWork: uow)
            self.transferCommands = TransferCommands(unitOfWork: uow)
        }

        var today: AcornDate { todayProvider.today() }
    }

    // MARK: - add

    @Test("opens an account with name and notes")
    func addOpensWithNameAndNotes() async throws {
        let sut = SUT()

        let account = try await sut.accountCommands.add(name: "Checking", notes: "Primary")

        #expect(account.name == "Checking")
        #expect(account.notes == "Primary")
        #expect(account.isClosed == false)

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Checking")
        #expect(stored?.notes == "Primary")
    }

    @Test("open writes no transactions")
    func addWritesNoTransactions() async throws {
        let sut = SUT()

        let account = try await sut.accountCommands.add(name: "Savings")
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)

        #expect(txs.isEmpty)
    }

    @Test("rejects empty name")
    func addRejectsEmptyName() async throws {
        let sut = SUT()

        await #expect(throws: DomainError.invalidArgument("name must not be blank")) {
            _ = try await sut.accountCommands.add(name: "   ")
        }
        #expect(try await sut.accounts.fetchActive().isEmpty)
    }

    // MARK: - adjustBalance

    @Test("creates an adjustment transaction")
    func adjustBalanceCreatesAdjustment() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Checking")

        let tx = try await sut.accountCommands.adjustBalance(accountID: account.id, amount: -7)

        #expect(tx.amount == -7)
        #expect(tx.kind == .adjustment)
    }

    @Test("zero amount fails with invalidArgument")
    func adjustBalanceZeroAmountFails() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Checking")

        await #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try await sut.accountCommands.adjustBalance(accountID: account.id, amount: 0)
        }
    }

    @Test("fails on a closed account")
    func adjustBalanceFailsOnClosed() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Checking")
        var closed = try #require(try await sut.accounts.fetch(id: account.id))
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.accountCommands.adjustBalance(accountID: account.id, amount: 10)
        }
    }

    // MARK: - changeName

    @Test("renames the account, preserving notes")
    func changeNameRenamesAccount() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Old", notes: "keep me")

        try await sut.accountCommands.changeName(accountID: account.id, name: "New")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "New")
        #expect(stored?.notes == "keep me")
    }

    @Test("rejects empty name")
    func changeNameRejectsEmptyName() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Old")

        await #expect(throws: DomainError.self) {
            try await sut.accountCommands.changeName(accountID: account.id, name: "   ")
        }
        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Old")
    }

    @Test("fails for unknown account")
    func changeNameFailsForUnknown() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.accountCommands.changeName(accountID: UUID(), name: "Any")
        }
    }

    @Test("fails on a deleted account")
    func changeNameFailsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Old")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.accountCommands.changeName(accountID: account.id, name: "New")
        }
    }

    // MARK: - close

    @Test("zero balance closes the account and posts no adjustment")
    func closeZeroBalanceClosesCleanly() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")

        try await sut.accountCommands.close(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed)
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        #expect(txs.isEmpty)
    }

    @Test("positive balance posts negative adjustment and closes")
    func closePositiveBalanceZeroesAndCloses() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        _ = try await sut.transactionCommands.record(accountID: account.id, amount: 100, date: sut.today)

        try await sut.accountCommands.close(accountID: account.id)

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
    func closeNegativeBalanceZeroesAndCloses() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        _ = try await sut.transactionCommands.record(accountID: account.id, amount: -40, date: sut.today)

        try await sut.accountCommands.close(accountID: account.id)

        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        let adjustments = txs.filter { $0.kind == .adjustment }
        #expect(adjustments.count == 1)
        #expect(adjustments[0].amount == 40)
    }

    @Test("considers transfer legs when computing balance")
    func closeTransferContributesToBalance() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        let other = try await sut.accountCommands.add(name: "B")
        _ = try await sut.transferCommands.record(
            fromAccountID: other.id,
            toAccountID: account.id,
            amount: 30,
            date: sut.today
        )

        try await sut.accountCommands.close(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed)
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        let adjustments = txs.filter { $0.kind == .adjustment }
        #expect(adjustments.count == 1)
        #expect(adjustments[0].amount == -30)
    }

    @Test("ignores soft-deleted transactions when computing balance")
    func closeSoftDeletedTransactionsIgnored() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        let tx = try await sut.transactionCommands.record(accountID: account.id, amount: 50, date: sut.today)
        var deleted = try await sut.transactions.fetch(id: tx.id)!
        try deleted.delete()
        try await sut.transactions.save(deleted)

        try await sut.accountCommands.close(accountID: account.id)

        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        #expect(txs.contains { $0.kind == .adjustment } == false)
        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed)
    }

    @Test("fails for unknown account")
    func closeFailsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.accountCommands.close(accountID: UUID())
        }
    }

    @Test("fails when account is already closed")
    func closeFailsWhenAlreadyClosed() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        try await sut.accountCommands.close(accountID: account.id)

        await #expect(throws: DomainError.invalidState("account is already closed")) {
            try await sut.accountCommands.close(accountID: account.id)
        }
    }

    @Test("rolls back the zeroing adjustment when the account save fails")
    func closeRollbackOnAccountSaveFailure() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        _ = try await sut.transactionCommands.record(accountID: account.id, amount: 100, date: sut.today)
        sut.accounts.saveHook = { _ in throw InjectedFailure() }

        await #expect(throws: InjectedFailure.self) {
            try await sut.accountCommands.close(accountID: account.id)
        }

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed == false)
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)
        #expect(txs.contains { $0.kind == .adjustment } == false)
    }

    @Test("fails on a deleted account")
    func closeFailsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.accountCommands.close(accountID: account.id)
        }
    }

    // MARK: - delete

    @Test("fails for unknown account")
    func deleteFailsForUnknown() async throws {
        let sut = SUT()
        let missingID = UUID()
        await #expect(throws: ApplicationError.notFound(missingID)) {
            try await sut.accountCommands.delete(accountID: missingID)
        }
    }

    @Test("allowed on empty account")
    func deleteAllowedOnEmpty() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")

        try await sut.accountCommands.delete(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("blocked when balance is non-zero")
    func deleteBlockedByNonZeroBalance() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        _ = try await sut.transactionCommands.record(accountID: account.id, amount: 10, date: .today())

        await #expect(throws: ApplicationError.policyViolation("account cannot be deleted")) {
            try await sut.accountCommands.delete(accountID: account.id)
        }
    }

    @Test("allowed after close zeros the balance")
    func deleteAllowedAfterClose() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        _ = try await sut.transactionCommands.record(accountID: account.id, amount: 100, date: .today())
        try await sut.accountCommands.close(accountID: account.id)

        try await sut.accountCommands.delete(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("blocked when a transfer references the account")
    func deleteBlockedByTransfer() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        let other = try await sut.accountCommands.add(name: "B")
        _ = try await sut.transferCommands.record(
            fromAccountID: account.id,
            toAccountID: other.id,
            amount: 10,
            date: .today()
        )

        await #expect(throws: ApplicationError.policyViolation("account cannot be deleted")) {
            try await sut.accountCommands.delete(accountID: account.id)
        }
    }

    @Test("ignores soft-deleted transactions and transfer legs")
    func deleteIgnoresSoftDeletedHistory() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        let other = try await sut.accountCommands.add(name: "B")
        let tx = try await sut.transactionCommands.record(accountID: account.id, amount: 10, date: .today())
        var deletedTx = try await sut.transactions.fetch(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)
        let legs = try await sut.transferCommands.record(
            fromAccountID: account.id,
            toAccountID: other.id,
            amount: 5,
            date: .today()
        )
        let transferID = try #require(legs.from.transferID)
        try await sut.transferCommands.delete(transferID: transferID)

        try await sut.accountCommands.delete(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("fails when already deleted")
    func deleteFailsWhenAlreadyDeleted() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        try await sut.accountCommands.delete(accountID: account.id)

        await #expect(throws: DomainError.deleted) {
            try await sut.accountCommands.delete(accountID: account.id)
        }
    }

    // MARK: - reconcile

    @Test("promotes only cleared transactions to reconciled")
    func reconcilePromotesOnlyCleared() async throws {
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
    func reconcileNoClearedTransactions() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        let tx = try await sut.transactionCommands.record(accountID: account.id, amount: 10, date: sut.today)

        try await sut.accountCommands.reconcile(accountID: account.id)

        #expect(try #require(try await sut.transactions.fetch(id: tx.id)).status == .uncleared)
    }

    @Test("fails for unknown account")
    func reconcileFailsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.accountCommands.reconcile(accountID: UUID())
        }
    }

    @Test("fails on a closed account")
    func reconcileFailsOnClosed() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        try await sut.accountCommands.close(accountID: account.id)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            try await sut.accountCommands.reconcile(accountID: account.id)
        }
    }

    @Test("fails on a deleted account")
    func reconcileFailsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.accountCommands.reconcile(accountID: account.id)
        }
    }

    // MARK: - reopen

    @Test("flips closed to open")
    func reopenFlipsClosedToOpen() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        try await sut.accountCommands.close(accountID: account.id)

        try await sut.accountCommands.reopen(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed == false)
    }

    @Test("fails for unknown account")
    func reopenFailsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.accountCommands.reopen(accountID: UUID())
        }
    }

    @Test("fails when not closed")
    func reopenFailsWhenNotClosed() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")

        await #expect(throws: DomainError.invalidState("account is not closed")) {
            try await sut.accountCommands.reopen(accountID: account.id)
        }
    }

    @Test("fails on a deleted account")
    func reopenFailsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "A")
        try await sut.accountCommands.close(accountID: account.id)
        let closed = try #require(try await sut.accounts.fetch(id: account.id))
        var deleted = closed
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.accountCommands.reopen(accountID: account.id)
        }
    }

    // MARK: - updateMetadata

    @Test("updates notes, preserving name")
    func updateMetadataUpdatesNotes() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Salary", notes: "old rule")

        try await sut.accountCommands.updateMetadata(accountID: account.id, notes: "new rule")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Salary")
        #expect(stored?.notes == "new rule")
    }

    @Test("clears notes when given an empty string")
    func updateMetadataClearsNotes() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Acct", notes: "has rules")

        try await sut.accountCommands.updateMetadata(accountID: account.id, notes: "")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Acct")
        #expect(stored?.notes == "")
    }

    @Test("fails for unknown account")
    func updateMetadataFailsForUnknown() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.accountCommands.updateMetadata(accountID: UUID(), notes: "any")
        }
    }

    @Test("fails on a deleted account")
    func updateMetadataFailsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.accountCommands.add(name: "Old")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.accountCommands.updateMetadata(accountID: account.id, notes: "new")
        }
    }
}
