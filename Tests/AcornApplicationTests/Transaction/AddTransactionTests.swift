import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("AddTransaction")
struct AddTransactionTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Services
        let addTransaction: AddTransaction

        let seedAccount: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Services
            self.addTransaction = AddTransaction(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account
        }
    }

    private static let today = AcornDate.today()

    @Test("stores a regular transaction with the given signed amount")
    func storesSignedAmount() async throws {
        let sut = try await SUT()

        let inflow = try await sut.addTransaction(accountID: sut.seedAccount.id, amount: 50, date: Self.today)
        #expect(inflow.amount == 50)
        #expect(inflow.kind == .regular)
        let storedIn = try await sut.transactions.fetch(id: inflow.id)
        #expect(storedIn?.amount == 50)

        let outflow = try await sut.addTransaction(accountID: sut.seedAccount.id, amount: -30, date: Self.today)
        #expect(outflow.amount == -30)
        #expect(outflow.kind == .regular)
    }

    @Test("fails for unknown account")
    func failsForUnknownAccount() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.self) {
            _ = try await sut.addTransaction(accountID: UUID(), amount: 10, date: Self.today)
        }
    }

    @Test("fails on a closed account")
    func failsOnClosedAccount() async throws {
        let sut = try await SUT()
        var closed = sut.seedAccount
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.addTransaction(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeletedAccount() async throws {
        let sut = try await SUT()
        var deleted = sut.seedAccount
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            _ = try await sut.addTransaction(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        }
    }
}
