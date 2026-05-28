import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("UpdateAccountMetadata")
struct UpdateAccountMetadataTests {
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

    @Test("updates notes, preserving name")
    func updatesNotes() async throws {
        let sut = SUT()
        let account = try await sut.commands.add(name: "Salary", notes: "old rule")

        try await sut.commands.updateMetadata(accountID: account.id, notes: "new rule")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Salary")
        #expect(stored?.notes == "new rule")
    }

    @Test("clears notes when given an empty string")
    func clearsNotes() async throws {
        let sut = SUT()
        let account = try await sut.commands.add(name: "Acct", notes: "has rules")

        try await sut.commands.updateMetadata(accountID: account.id, notes: "")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Acct")
        #expect(stored?.notes == "")
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.updateMetadata(accountID: UUID(), notes: "any")
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
            try await sut.commands.updateMetadata(accountID: account.id, notes: "new")
        }
    }
}
