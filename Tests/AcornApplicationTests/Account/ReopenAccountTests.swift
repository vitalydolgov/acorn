import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ReopenAccount")
struct ReopenAccountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork
        let todayProvider: TodayProvider

        // Repos
        let accounts: InMemoryAccountRepository

        // Services
        let openAccount: OpenAccount
        let closeAccount: CloseAccount
        let reopenAccount: ReopenAccount

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()

            self.uow = InMemoryUnitOfWork(
                accounts: accounts,
                transactions: transactions,
                transfers: transfers
            )
            self.todayProvider = FixedTodayProvider(date: .today())

            // Repos
            self.accounts = accounts

            // Services
            self.openAccount = OpenAccount(unitOfWork: uow)
            self.closeAccount = CloseAccount(
                unitOfWork: uow,
                todayProvider: todayProvider
            )
            self.reopenAccount = ReopenAccount(unitOfWork: uow)
        }

        var today: AcornDate { todayProvider.today() }
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
        await #expect(throws: ApplicationError.self) {
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
