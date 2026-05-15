import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("DeleteTransaction")
struct DeleteTransactionTests {
    private struct SUT {
        let postTransaction: PostTransaction
        let deleteTransaction: DeleteTransaction
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
            self.deleteTransaction = DeleteTransaction(transactionRepository: transactions)
        }

        func post() async throws -> Transaction {
            try await postTransaction(accountID: account.id, amount: 10, date: .today())
        }
    }

    @Test("marks transaction deleted")
    func marksDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()

        try await sut.deleteTransaction(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.get(id: tx.id))
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
}
