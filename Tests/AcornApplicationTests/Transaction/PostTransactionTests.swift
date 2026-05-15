import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("PostTransaction")
struct PostTransactionTests {
    private struct SUT {
        let postTransaction: PostTransaction
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository
        let account: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            self.accounts = accounts
            self.transactions = transactions
            self.account = account
            self.postTransaction = PostTransaction(
                accountRepository: accounts,
                transactionRepository: transactions
            )
        }
    }

    private static let today = AcornDate.today()

    @Test("stores a regular transaction with the given signed amount")
    func storesSignedAmount() async throws {
        let sut = try await SUT()

        let inflow = try await sut.postTransaction(accountID: sut.account.id, amount: 50, date: Self.today)
        #expect(inflow.amount == 50)
        #expect(inflow.kind == .regular)
        let storedIn = try await sut.transactions.get(id: inflow.id)
        #expect(storedIn?.amount == 50)

        let outflow = try await sut.postTransaction(accountID: sut.account.id, amount: -30, date: Self.today)
        #expect(outflow.amount == -30)
        #expect(outflow.kind == .regular)
    }

    @Test("fails for unknown account")
    func failsForUnknownAccount() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.notFound) {
            _ = try await sut.postTransaction(accountID: UUID(), amount: 10, date: Self.today)
        }
    }

    @Test("fails on a closed account")
    func failsOnClosedAccount() async throws {
        let sut = try await SUT()
        var closed = sut.account
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.postTransaction(accountID: sut.account.id, amount: 10, date: Self.today)
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeletedAccount() async throws {
        let sut = try await SUT()
        var deleted = sut.account
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            _ = try await sut.postTransaction(accountID: sut.account.id, amount: 10, date: Self.today)
        }
    }
}
