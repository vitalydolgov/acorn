import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("UpdateTransaction")
struct UpdateTransactionTests {
    private struct SUT {
        let postTransaction: PostTransaction
        let updateTransaction: UpdateTransaction
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
            self.updateTransaction = UpdateTransaction(transactionRepository: transactions)
        }
    }

    private static let today = AcornDate.today()

    @Test("updates amount and date")
    func updatesAmountAndDate() async throws {
        let sut = try await SUT()
        let tx = try await sut.postTransaction(accountID: sut.account.id, amount: 10, date: Self.today)
        let newDate = Self.today.adding(days: 1)

        try await sut.updateTransaction(transactionID: tx.id, amount: 25, date: newDate)

        let stored = try await sut.transactions.get(id: tx.id)
        #expect(stored?.amount == 25)
        #expect(stored?.date == newDate)
    }

    @Test("fails for unknown transaction")
    func failsForUnknown() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.notFound) {
            try await sut.updateTransaction(transactionID: UUID(), amount: 1, date: Self.today)
        }
    }

    @Test("fails on a deleted transaction")
    func failsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.postTransaction(accountID: sut.account.id, amount: 10, date: Self.today)
        var deletedTx = tx
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.updateTransaction(transactionID: tx.id, amount: 99, date: Self.today)
        }
    }
}
