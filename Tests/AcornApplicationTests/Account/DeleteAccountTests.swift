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
        let transfers: InMemoryTransferRepository

        // Services
        let openAccount: OpenAccount
        let addTransaction: AddTransaction
        let recordTransfer: RecordTransfer
        let deleteAccount: DeleteAccount

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions, transfers: transfers)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions
            self.transfers = transfers

            // Services
            self.openAccount = OpenAccount(unitOfWork: uow)
            self.addTransaction = AddTransaction(unitOfWork: uow)
            self.recordTransfer = RecordTransfer(unitOfWork: uow)
            self.deleteAccount = DeleteAccount(unitOfWork: uow)
        }
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.deleteAccount(accountID: UUID())
        }
    }

    @Test("allowed on empty account")
    func allowedOnEmpty() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")

        try await sut.deleteAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isDeleted == true)
    }

    @Test("blocked when regular transactions exist")
    func blockedByTransactions() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        _ = try await sut.addTransaction(accountID: account.id, amount: 10, date: .today())

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.deleteAccount(accountID: account.id)
        }
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

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.deleteAccount(accountID: account.id)
        }
    }

    @Test("ignores soft-deleted transactions and transfers")
    func ignoresSoftDeletedHistory() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        let other = try await sut.openAccount(name: "B")
        let tx = try await sut.addTransaction(accountID: account.id, amount: 10, date: .today())
        var deletedTx = try await sut.transactions.get(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)
        let transfer = try await sut.recordTransfer(
            fromAccountID: account.id,
            toAccountID: other.id,
            amount: 5,
            date: .today()
        )
        var deletedTransfer = try await sut.transfers.get(id: transfer.id)!
        try deletedTransfer.delete()
        try await sut.transfers.save(deletedTransfer)

        try await sut.deleteAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
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
