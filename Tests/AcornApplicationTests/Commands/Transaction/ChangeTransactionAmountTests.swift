import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ChangeTransactionAmount")
struct ChangeTransactionAmountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transactions: InMemoryTransactionRepository

        // Commands
        let commands: TransactionCommands

        let seedAccount: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.transactions = transactions

            // Commands
            self.commands = TransactionCommands(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account
        }
    }

    private static let today = AcornDate.today()

    @Test("updates amount, preserving date")
    func updatesAmount() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)

        try await sut.commands.changeAmount(transactionID: tx.id, amount: 25)

        let stored = try await sut.transactions.fetch(id: tx.id)
        #expect(stored?.amount == 25)
        #expect(stored?.date == Self.today)
    }

    @Test("fails for unknown transaction")
    func failsForUnknown() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeAmount(transactionID: UUID(), amount: 1)
        }
    }

    @Test("fails on a deleted transaction")
    func failsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        var deletedTx = try await sut.transactions.fetch(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.changeAmount(transactionID: tx.id, amount: 99)
        }
    }

    @Test("rejects editing a transfer leg directly")
    func rejectsTransferLeg() async throws {
        let sut = try await SUT()
        let legs = try Transaction.transfer(
            fromAccountID: sut.seedAccount.id,
            toAccountID: UUID(),
            amount: 10,
            date: Self.today
        )
        try await sut.transactions.save(legs.from)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeAmount(transactionID: legs.from.id, amount: 5)
        }
    }
}
