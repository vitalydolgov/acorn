import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("TransactionLifecycle")
struct TransactionLifecycleTests {
    private struct SUT {
        let lifecycle: TransactionLifecycle
        let createUpdate: TransactionCreateUpdate
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository
        let account: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let account = try #require(Account.make(name: "Checking", notes: ""))
            try await accounts.save(account)
            self.accounts = accounts
            self.transactions = transactions
            self.account = account
            self.lifecycle = TransactionLifecycle(transactionRepository: transactions)
            self.createUpdate = TransactionCreateUpdate(
                accountRepository: accounts,
                transactionRepository: transactions
            )
        }

        func post(_ amount: Decimal) async throws -> Transaction {
            try await createUpdate.post(accountID: account.id, amount: amount, date: .today())
        }
    }

    // MARK: - Clear

    @Test("clear flips uncleared to cleared")
    func clearFlipsUnclearedToCleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)

        try await sut.lifecycle.clear(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.get(id: tx.id))
        #expect(stored.status == .cleared)
    }

    @Test("clear fails when not uncleared")
    func clearFailsWhenNotUncleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)
        try await sut.lifecycle.clear(transactionID: tx.id)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.clear(transactionID: tx.id)
        }
    }

    @Test("clear fails for unknown transaction")
    func clearFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.lifecycle.clear(transactionID: UUID())
        }
    }

    @Test("clear fails on a deleted transaction")
    func clearFailsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)
        try await sut.transactions.save(tx.deleted())

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.clear(transactionID: tx.id)
        }
    }

    // MARK: - Unclear

    @Test("unclear flips cleared to uncleared")
    func unclearFlipsClearedToUncleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)
        try await sut.lifecycle.clear(transactionID: tx.id)

        try await sut.lifecycle.unclear(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.get(id: tx.id))
        #expect(stored.status == .uncleared)
    }

    @Test("unclear fails when not cleared")
    func unclearFailsWhenNotCleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.unclear(transactionID: tx.id)
        }
    }

    @Test("unclear fails on reconciled")
    func unclearFailsOnReconciled() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)
        try await sut.lifecycle.clear(transactionID: tx.id)
        try await sut.lifecycle.reconcile(transactionID: tx.id)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.unclear(transactionID: tx.id)
        }
    }

    @Test("unclear fails for unknown transaction")
    func unclearFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.lifecycle.unclear(transactionID: UUID())
        }
    }

    @Test("unclear fails on a deleted transaction")
    func unclearFailsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)
        try await sut.lifecycle.clear(transactionID: tx.id)
        let cleared = try #require(try await sut.transactions.get(id: tx.id))
        try await sut.transactions.save(cleared.deleted())

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.unclear(transactionID: tx.id)
        }
    }

    // MARK: - Reconcile

    @Test("reconcile promotes cleared to reconciled")
    func reconcilePromotesClearedToReconciled() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)
        try await sut.lifecycle.clear(transactionID: tx.id)

        try await sut.lifecycle.reconcile(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.get(id: tx.id))
        #expect(stored.status == .reconciled)
    }

    @Test("reconcile fails on uncleared")
    func reconcileFailsOnUncleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.reconcile(transactionID: tx.id)
        }
    }

    @Test("reconcile fails for unknown transaction")
    func reconcileFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.lifecycle.reconcile(transactionID: UUID())
        }
    }

    @Test("reconcile fails on a deleted transaction")
    func reconcileFailsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)
        try await sut.lifecycle.clear(transactionID: tx.id)
        let cleared = try #require(try await sut.transactions.get(id: tx.id))
        try await sut.transactions.save(cleared.deleted())

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.reconcile(transactionID: tx.id)
        }
    }

    // MARK: - Delete

    @Test("delete marks transaction deleted")
    func deleteMarksDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)

        try await sut.lifecycle.delete(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.get(id: tx.id))
        #expect(stored.isDeleted == true)
    }

    @Test("delete fails when already deleted")
    func deleteFailsWhenAlreadyDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post(10)
        try await sut.lifecycle.delete(transactionID: tx.id)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.lifecycle.delete(transactionID: tx.id)
        }
    }
}
