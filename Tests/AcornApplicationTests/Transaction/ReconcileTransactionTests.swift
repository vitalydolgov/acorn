import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ReconcileTransaction")
struct ReconcileTransactionTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transactions: InMemoryTransactionRepository

        // Services
        let addTransaction: AddTransaction
        let clearTransaction: ClearTransaction
        let reconcileTransaction: ReconcileTransaction

        let seedAccount: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.transactions = transactions

            // Services
            self.addTransaction = AddTransaction(unitOfWork: uow)
            self.clearTransaction = ClearTransaction(unitOfWork: uow)
            self.reconcileTransaction = ReconcileTransaction(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account
        }

        func post() async throws -> Transaction {
            try await addTransaction(accountID: seedAccount.id, amount: 10, date: .today())
        }
    }

    @Test("promotes cleared to reconciled")
    func promotesClearedToReconciled() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.clearTransaction(transactionID: tx.id)

        try await sut.reconcileTransaction(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.status == .reconciled)
    }

    @Test("fails on uncleared")
    func failsOnUncleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()

        await #expect(throws: DomainError.invalidState("transaction is not cleared")) {
            try await sut.reconcileTransaction(transactionID: tx.id)
        }
    }

    @Test("fails for unknown transaction")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.reconcileTransaction(transactionID: UUID())
        }
    }

    @Test("fails on a deleted transaction")
    func failsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.clearTransaction(transactionID: tx.id)
        let cleared = try #require(try await sut.transactions.fetch(id: tx.id))
        var deletedTx = cleared
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.reconcileTransaction(transactionID: tx.id)
        }
    }
}
