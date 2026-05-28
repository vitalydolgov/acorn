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

        // Commands
        let commands: AccountCommands

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()

            self.uow = InMemoryUnitOfWork(
                accounts: accounts,
                transactions: transactions
            )
            self.todayProvider = FixedTodayProvider(date: .today())

            // Repos
            self.accounts = accounts

            // Commands
            self.commands = AccountCommands(unitOfWork: uow, todayProvider: todayProvider)
        }

        var today: AcornDate { todayProvider.today() }
    }

    @Test("flips closed to open")
    func flipsClosedToOpen() async throws {
        let sut = SUT()
        let account = try await sut.commands.add(name: "A")
        try await sut.commands.close(accountID: account.id)

        try await sut.commands.reopen(accountID: account.id)

        let stored = try #require(try await sut.accounts.fetch(id: account.id))
        #expect(stored.isClosed == false)
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.reopen(accountID: UUID())
        }
    }

    @Test("fails when not closed")
    func failsWhenNotClosed() async throws {
        let sut = SUT()
        let account = try await sut.commands.add(name: "A")

        await #expect(throws: DomainError.invalidState("account is not closed")) {
            try await sut.commands.reopen(accountID: account.id)
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.commands.add(name: "A")
        try await sut.commands.close(accountID: account.id)
        let closed = try #require(try await sut.accounts.fetch(id: account.id))
        var deleted = closed
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.reopen(accountID: account.id)
        }
    }
}
