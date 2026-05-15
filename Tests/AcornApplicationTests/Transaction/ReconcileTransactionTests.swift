import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("ReconcileTransaction")
struct ReconcileTransactionTests {
    private struct SUT {
        let postTransaction: PostTransaction
        let clearTransaction: ClearTransaction
        let reconcileTransaction: ReconcileTransaction
        let transactions: InMemoryTransactionRepository
        let account: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            self.transactions = transactions
            self.account = account
            self.postTransaction = PostTransaction(
                accountRepository: accounts,
                transactionRepository: transactions
            )
            self.clearTransaction = ClearTransaction(transactionRepository: transactions)
            self.reconcileTransaction = ReconcileTransaction(transactionRepository: transactions)
        }

        func post() async throws -> Transaction {
            try await postTransaction(accountID: account.id, amount: 10, date: .today())
        }
    }

    @Test("promotes cleared to reconciled")
    func promotesClearedToReconciled() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.clearTransaction(transactionID: tx.id)

        try await sut.reconcileTransaction(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.get(id: tx.id))
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
        await #expect(throws: ApplicationError.notFound) {
            try await sut.reconcileTransaction(transactionID: UUID())
        }
    }

    @Test("fails on a deleted transaction")
    func failsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.clearTransaction(transactionID: tx.id)
        let cleared = try #require(try await sut.transactions.get(id: tx.id))
        var deletedTx = cleared
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.reconcileTransaction(transactionID: tx.id)
        }
    }
}
