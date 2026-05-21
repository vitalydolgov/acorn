import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ClearTransaction")
struct ClearTransactionTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transactions: InMemoryTransactionRepository

        // Services
        let addTransaction: AddTransaction
        let clearTransaction: ClearTransaction

        let seedAccount: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions, transfers: transfers)
            self.uow = uow

            // Repos
            self.transactions = transactions

            // Services
            self.addTransaction = AddTransaction(unitOfWork: uow)
            self.clearTransaction = ClearTransaction(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account
        }

        func post(_ amount: Decimal = 10) async throws -> Transaction {
            try await addTransaction(accountID: seedAccount.id, amount: amount, date: .today())
        }
    }

    @Test("flips uncleared to cleared")
    func flipsUnclearedToCleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()

        try await sut.clearTransaction(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.status == .cleared)
    }

    @Test("fails when not uncleared")
    func failsWhenNotUncleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.clearTransaction(transactionID: tx.id)

        await #expect(throws: DomainError.invalidState("transaction is not uncleared")) {
            try await sut.clearTransaction(transactionID: tx.id)
        }
    }

    @Test("fails for unknown transaction")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.clearTransaction(transactionID: UUID())
        }
    }

    @Test("fails on a deleted transaction")
    func failsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        var deletedTx = try await sut.transactions.fetch(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.clearTransaction(transactionID: tx.id)
        }
    }
}
