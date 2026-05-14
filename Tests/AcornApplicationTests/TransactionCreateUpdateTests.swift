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
            let account = try Account.make(name: "Checking", notes: "")
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
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.createUpdate.post(accountID: sut.account.id, amount: 10, date: Self.today)
        }
    }

    @Test("create fails on a deleted account")
    func createFailsOnDeletedAccount() async throws {
        let sut = try await SUT()
        var deleted = sut.account
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
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
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.createUpdate.update(transactionID: tx.id, amount: 99, date: Self.today)
        }
    }

    // MARK: - Transfer

    @Test("transfer stores a linked outflow/inflow pair")
    func transferStoresLinkedPair() async throws {
        let sut = try await SUT()
        let other = try Account.make(name: "Savings", notes: "")
        try await sut.accounts.save(other)

        let pair = try await sut.createUpdate.transfer(
            fromAccountID: sut.account.id,
            toAccountID: other.id,
            amount: 100,
            date: Self.today
        )

        let storedOut = try await sut.transactions.get(id: pair.outflow.id)
        let storedIn = try await sut.transactions.get(id: pair.inflow.id)
        #expect(storedOut?.amount == -100)
        #expect(storedIn?.amount == 100)
        #expect(storedOut?.kind == .transfer(counterpartID: pair.inflow.id))
        #expect(storedIn?.kind == .transfer(counterpartID: pair.outflow.id))
    }

    @Test("transfer fails when either account is unknown")
    func transferFailsForUnknownAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.notFound) {
            _ = try await sut.createUpdate.transfer(
                fromAccountID: sut.account.id,
                toAccountID: UUID(),
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("transfer fails when accounts are the same")
    func transferFailsForSameAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("source and destination must differ")) {
            _ = try await sut.createUpdate.transfer(
                fromAccountID: sut.account.id,
                toAccountID: sut.account.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    // MARK: - Zero amount

    @Test("adjust with zero amount fails with invalidArgument")
    func adjustZeroFails() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try await sut.createUpdate.adjust(accountID: sut.account.id, amount: 0, date: Self.today)
        }
    }
}
