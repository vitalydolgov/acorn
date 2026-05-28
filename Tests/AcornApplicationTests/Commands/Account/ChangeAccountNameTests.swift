import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ChangeAccountName")
struct ChangeAccountNameTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository

        // Commands
        let commands: AccountCommands

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts

            // Commands
            self.commands = AccountCommands(unitOfWork: uow, todayProvider: FixedTodayProvider(date: .today()))
        }
    }

    @Test("renames the account, preserving notes")
    func renamesAccount() async throws {
        let sut = SUT()
        let account = try await sut.commands.add(name: "Old", notes: "keep me")

        try await sut.commands.changeName(accountID: account.id, name: "New")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "New")
        #expect(stored?.notes == "keep me")
    }

    @Test("rejects empty name")
    func rejectsEmptyName() async throws {
        let sut = SUT()
        let account = try await sut.commands.add(name: "Old")

        await #expect(throws: DomainError.self) {
            try await sut.commands.changeName(accountID: account.id, name: "   ")
        }
        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Old")
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeName(accountID: UUID(), name: "Any")
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.commands.add(name: "Old")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.changeName(accountID: account.id, name: "New")
        }
    }
}
