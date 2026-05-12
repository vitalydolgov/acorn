import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("AccountLifecycle")
struct AccountLifecycleTests {
    private struct SUT {
        let lifecycle: AccountLifecycle
        let createUpdate: AccountCreateUpdate
        let transactionCreateUpdate: TransactionCreateUpdate
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        init(today: AcornDate = .today()) {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let provider = FixedTodayProvider(date: today)
            self.accounts = accounts
            self.transactions = transactions
            self.lifecycle = AccountLifecycle(
                accountRepository: accounts,
                transactionRepository: transactions,
                todayProvider: provider
            )
            self.createUpdate = AccountCreateUpdate(
                accountRepository: accounts,
                transactionRepository: transactions,
                todayProvider: provider
            )
            self.transactionCreateUpdate = TransactionCreateUpdate(
                accountRepository: accounts,
                transactionRepository: transactions
            )
        }
    }

    // MARK: - Close

    @Test("close marks account closed and zeros non-zero balance")
    func closeZerosBalance() async throws {
        let today = AcornDate.today()
        let sut = SUT(today: today)
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 100)

        try await sut.lifecycle.close(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isClosed == true)
        let txs = try await sut.transactions.forAccount(account.id)
        #expect(BalanceCalculator.balance(of: txs) == 0)
        #expect(txs.contains { $0.kind == .adjustment && $0.amount == -100 && $0.date == today })
    }

    @Test("close on zero balance does not create adjustment")
    func closeZeroBalanceNoAdjustment() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)

        try await sut.lifecycle.close(accountID: account.id)

        let txs = try await sut.transactions.forAccount(account.id)
        #expect(txs.isEmpty)
    }

    @Test("close fails for unknown account")
    func closeFailsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.lifecycle.close(accountID: UUID())
        }
    }

    @Test("close fails when already closed")
    func closeFailsWhenAlreadyClosed() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)
        try await sut.lifecycle.close(accountID: account.id)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.close(accountID: account.id)
        }
    }

    @Test("close fails on a deleted account")
    func closeFailsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)
        try await sut.accounts.save(account.deleted())

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.close(accountID: account.id)
        }
    }

    // MARK: - Reopen

    @Test("reopen flips closed to open")
    func reopenFlipsClosedToOpen() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)
        try await sut.lifecycle.close(accountID: account.id)

        try await sut.lifecycle.reopen(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isClosed == false)
    }

    @Test("reopen fails for unknown account")
    func reopenFailsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.lifecycle.reopen(accountID: UUID())
        }
    }

    @Test("reopen fails when not closed")
    func reopenFailsWhenNotClosed() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.reopen(accountID: account.id)
        }
    }

    @Test("reopen fails on a deleted account")
    func reopenFailsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)
        try await sut.lifecycle.close(accountID: account.id)
        let closed = try #require(try await sut.accounts.get(id: account.id))
        try await sut.accounts.save(closed.deleted())

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.reopen(accountID: account.id)
        }
    }

    // MARK: - Delete

    @Test("delete fails for unknown account")
    func deleteFailsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.lifecycle.delete(accountID: UUID())
        }
    }

    @Test("delete allowed on empty account")
    func deleteAllowedOnEmpty() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)

        try await sut.lifecycle.delete(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("delete allowed with a single starting transaction")
    func deleteAllowedWithStartingOnly() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 50)

        try await sut.lifecycle.delete(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("delete blocked when regular transactions exist")
    func deleteBlockedWithRegularTransactions() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)
        _ = try await sut.transactionCreateUpdate.post(accountID: account.id, amount: 10, date: .today())

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.delete(accountID: account.id)
        }
    }

    @Test("delete ignores soft-deleted transactions")
    func deleteIgnoresSoftDeletedTransactions() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)
        let tx = try await sut.transactionCreateUpdate.post(accountID: account.id, amount: 10, date: .today())
        try await sut.transactions.save(tx.deleted())

        try await sut.lifecycle.delete(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("delete fails when already deleted")
    func deleteFailsWhenAlreadyDeleted() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "A", openingBalance: 0)
        try await sut.lifecycle.delete(accountID: account.id)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.delete(accountID: account.id)
        }
    }
}
