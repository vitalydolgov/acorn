import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("DeleteTransaction")
struct DeleteTransactionTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transactions: InMemoryTransactionRepository

        // Services
        let addTransaction: AddTransaction
        let deleteTransaction: DeleteTransaction

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
            self.deleteTransaction = DeleteTransaction(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account
        }

        func post() async throws -> Transaction {
            try await addTransaction(accountID: seedAccount.id, amount: 10, date: .today())
        }
    }

    @Test("marks transaction deleted")
    func marksDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()

        try await sut.deleteTransaction(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.isDeleted == true)
    }

    @Test("fails when already deleted")
    func failsWhenAlreadyDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.deleteTransaction(transactionID: tx.id)

        await #expect(throws: DomainError.deleted) {
            try await sut.deleteTransaction(transactionID: tx.id)
        }
    }

    @Test("rejects deleting a transfer leg directly")
    func rejectsTransferLeg() async throws {
        let sut = try await SUT()
        let legs = try Transaction.transfer(
            fromAccountID: sut.seedAccount.id,
            toAccountID: UUID(),
            amount: 10,
            date: .today()
        )
        try await sut.transactions.save(legs.from)

        await #expect(throws: ApplicationError.self) {
            try await sut.deleteTransaction(transactionID: legs.from.id)
        }
    }
}
