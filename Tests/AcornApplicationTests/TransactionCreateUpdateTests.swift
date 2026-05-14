import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("TransactionCreateUpdate")
struct TransactionCreateUpdateTests {
    private struct SUT {
        let createUpdate: TransactionCreateUpdate
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository
        let account: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let account = try #require(Account.make(name: "Checking", notes: ""))
            try await accounts.save(account)
            self.accounts = accounts
            self.transactions = transactions
            self.account = account
            self.createUpdate = TransactionCreateUpdate(
                accountRepository: accounts,
                transactionRepository: transactions
            )
        }
    }

    private static let today = AcornDate.today()

    // MARK: - Create

    @Test("post stores a regular transaction with the given signed amount")
    func postStoresSignedAmount() async throws {
        let sut = try await SUT()

        let inflow = try await sut.createUpdate.post(accountID: sut.account.id, amount: 50, date: Self.today)
        #expect(inflow.amount == 50)
        #expect(inflow.kind == .regular)
        let storedIn = try await sut.transactions.get(id: inflow.id)
        #expect(storedIn?.amount == 50)

        let outflow = try await sut.createUpdate.post(accountID: sut.account.id, amount: -30, date: Self.today)
        #expect(outflow.amount == -30)
        #expect(outflow.kind == .regular)
    }

    @Test("adjust creates an adjustment transaction")
    func adjustCreatesAdjustment() async throws {
        let sut = try await SUT()

        let tx = try await sut.createUpdate.adjust(accountID: sut.account.id, amount: -7, date: Self.today)

        #expect(tx.amount == -7)
        #expect(tx.kind == .adjustment)
    }

    @Test("create fails for unknown account")
    func createFailsForUnknownAccount() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.notFound) {
            _ = try await sut.createUpdate.post(accountID: UUID(), amount: 10, date: Self.today)
        }
    }

    @Test("create fails on a closed account")
    func createFailsOnClosedAccount() async throws {
        let sut = try await SUT()
        var closed = sut.account
        closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: ApplicationError.invalidState) {
            _ = try await sut.createUpdate.post(accountID: sut.account.id, amount: 10, date: Self.today)
        }
    }

    @Test("create fails on a deleted account")
    func createFailsOnDeletedAccount() async throws {
        let sut = try await SUT()
        var deleted = sut.account
        deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: ApplicationError.invalidState) {
            _ = try await sut.createUpdate.post(accountID: sut.account.id, amount: 10, date: Self.today)
        }
    }

    // MARK: - Update

    @Test("updates amount and date")
    func updatesAmountAndDate() async throws {
        let sut = try await SUT()
        let tx = try await sut.createUpdate.post(accountID: sut.account.id, amount: 10, date: Self.today)
        let newDate = Self.today.adding(days: 1)

        try await sut.createUpdate.update(transactionID: tx.id, amount: 25, date: newDate)

        let stored = try await sut.transactions.get(id: tx.id)
        #expect(stored?.amount == 25)
        #expect(stored?.date == newDate)
    }

    @Test("update fails for unknown transaction")
    func updateFailsForUnknownTransaction() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.notFound) {
            try await sut.createUpdate.update(transactionID: UUID(), amount: 1, date: Self.today)
        }
    }

    @Test("update fails on a deleted transaction")
    func updateFailsOnDeletedTransaction() async throws {
        let sut = try await SUT()
        let tx = try await sut.createUpdate.post(accountID: sut.account.id, amount: 10, date: Self.today)
        var deletedTx = tx
        deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.createUpdate.update(transactionID: tx.id, amount: 99, date: Self.today)
        }
    }

    // MARK: - Zero amount

    @Test("adjust with zero amount fails with invalidArgument")
    func adjustZeroFails() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.invalidArgument("amount")) {
            _ = try await sut.createUpdate.adjust(accountID: sut.account.id, amount: 0, date: Self.today)
        }
    }
}
