import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("ReopenAccount")
struct ReopenAccountTests {
    private struct SUT {
        let openAccount: OpenAccount
        let closeAccount: CloseAccount
        let reopenAccount: ReopenAccount
        let accounts: InMemoryAccountRepository

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            self.accounts = accounts
            self.openAccount = OpenAccount(accountRepository: accounts)
            let uow = InMemoryUnitOfWork(
                accounts: accounts,
                transactions: transactions,
                transfers: transfers
            )
            self.closeAccount = CloseAccount(
                unitOfWork: uow,
                todayProvider: FixedTodayProvider(date: .today())
            )
            self.reopenAccount = ReopenAccount(accountRepository: accounts)
        }
    }

    @Test("flips closed to open")
    func flipsClosedToOpen() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        try await sut.closeAccount(accountID: account.id)

        try await sut.reopenAccount(accountID: account.id)

        let stored = try #require(try await sut.accounts.get(id: account.id))
        #expect(stored.isClosed == false)
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.reopenAccount(accountID: UUID())
        }
    }

    @Test("fails when not closed")
    func failsWhenNotClosed() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")

        await #expect(throws: DomainError.invalidState("account is not closed")) {
            try await sut.reopenAccount(accountID: account.id)
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "A")
        try await sut.closeAccount(accountID: account.id)
        let closed = try #require(try await sut.accounts.get(id: account.id))
        var deleted = closed
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.reopenAccount(accountID: account.id)
        }
    }
}
