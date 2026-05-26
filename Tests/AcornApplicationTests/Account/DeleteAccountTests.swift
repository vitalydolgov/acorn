import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("DeleteAccount")
struct DeleteAccountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Services
        let openAccount: OpenAccount
        let recordTransaction: RecordTransaction
        let recordTransfer: RecordTransfer
        let deleteTransfer: DeleteTransfer
        let closeAccount: CloseAccount
        let deleteAccount: DeleteAccount

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Services
            self.openAccount = OpenAccount(unitOfWork: uow)
            self.recordTransaction = RecordTransaction(unitOfWork: uow)
            self.recordTransfer = RecordTransfer(unitOfWork: uow)
            self.deleteTransfer = DeleteTransfer(unitOfWork: uow)
            self.closeAccount = CloseAccount(
                unitOfWork: uow,
                todayProvider: FixedTodayProvider(date: .today())
            )
            self.deleteAccount = DeleteAccount(unitOfWork: uow)
        }
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()
        let missingID = UUID()
        await #expect(throws: ApplicationError.notFound(missingID)) {
            try await sut.deleteAccount(accountID: missingID)
        }
    }

    @Test("allowed on empty account")
    func allowedOnEmpty() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")

        try await sut.deleteAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("blocked when balance is non-zero")
    func blockedByNonZeroBalance() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        _ = try await sut.recordTransaction(accountID: account.id, amount: 10, date: .today())

        await #expect(throws: ApplicationError.policyViolation("account cannot be deleted")) {
            try await sut.deleteAccount(accountID: account.id)
        }
    }

    @Test("allowed after close zeros the balance")
    func allowedAfterClose() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        _ = try await sut.recordTransaction(accountID: account.id, amount: 100, date: .today())
        try await sut.closeAccount(accountID: account.id)

        try await sut.deleteAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("blocked when a transfer references the account")
    func blockedByTransfer() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        let other = try await sut.openAccount(name: "B")
        _ = try await sut.recordTransfer(
            fromAccountID: account.id,
            toAccountID: other.id,
            amount: 10,
            date: .today()
        )

        await #expect(throws: ApplicationError.policyViolation("account cannot be deleted")) {
            try await sut.deleteAccount(accountID: account.id)
        }
    }

    @Test("ignores soft-deleted transactions and transfer legs")
    func ignoresSoftDeletedHistory() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        let other = try await sut.openAccount(name: "B")
        let tx = try await sut.recordTransaction(accountID: account.id, amount: 10, date: .today())
        var deletedTx = try await sut.transactions.fetch(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)
        let legs = try await sut.recordTransfer(
            fromAccountID: account.id,
            toAccountID: other.id,
            amount: 5,
            date: .today()
        )
        let transferID = try #require(legs.from.transferID)
        try await sut.deleteTransfer(transferID: transferID)

        try await sut.deleteAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("fails when already deleted")
    func failsWhenAlreadyDeleted() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        try await sut.deleteAccount(accountID: account.id)

        await #expect(throws: DomainError.deleted) {
            try await sut.deleteAccount(accountID: account.id)
        }
    }
}
