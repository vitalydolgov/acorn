import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("UpdateTransaction")
struct UpdateTransactionTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transactions: InMemoryTransactionRepository

        // Services
        let addTransaction: AddTransaction
        let updateTransaction: UpdateTransaction

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
            self.updateTransaction = UpdateTransaction(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.get(id: account.id)!
            self.seedAccount = account
        }
    }

    private static let today = AcornDate.today()

    @Test("updates amount and date")
    func updatesAmountAndDate() async throws {
        let sut = try await SUT()
        let tx = try await sut.addTransaction(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        let newDate = Self.today.adding(days: 1)

        try await sut.updateTransaction(transactionID: tx.id, amount: 25, date: newDate)

        let stored = try await sut.transactions.get(id: tx.id)
        #expect(stored?.amount == 25)
        #expect(stored?.date == newDate)
    }

    @Test("fails for unknown transaction")
    func failsForUnknown() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.updateTransaction(transactionID: UUID(), amount: 1, date: Self.today)
        }
    }

    @Test("fails on a deleted transaction")
    func failsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.addTransaction(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        var deletedTx = try await sut.transactions.get(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.updateTransaction(transactionID: tx.id, amount: 99, date: Self.today)
        }
    }
}
