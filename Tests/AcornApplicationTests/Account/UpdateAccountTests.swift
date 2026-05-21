import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("UpdateAccount")
struct UpdateAccountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository

        // Services
        let openAccount: OpenAccount
        let updateAccount: UpdateAccount

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions, transfers: transfers)
            self.uow = uow

            // Repos
            self.accounts = accounts

            // Services
            self.openAccount = OpenAccount(unitOfWork: uow)
            self.updateAccount = UpdateAccount(unitOfWork: uow)
        }
    }

    @Test("updates name and notes")
    func updatesNameAndNotes() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Old", notes: "old notes")

        try await sut.updateAccount(accountID: account.id, name: "New", notes: "new notes")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "New")
        #expect(stored?.notes == "new notes")
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.updateAccount(accountID: UUID(), name: "Any", notes: "")
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Old")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.updateAccount(accountID: account.id, name: "New", notes: "")
        }
    }

    @Test("rejects empty name")
    func rejectsEmptyName() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Old")

        await #expect(throws: DomainError.self) {
            try await sut.updateAccount(accountID: account.id, name: "   ", notes: "")
        }
        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Old")
    }

    @Test("updating notes only leaves the name unchanged")
    func notesOnlyPreservesName() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Salary", notes: "old rule")

        try await sut.updateAccount(accountID: account.id, notes: "new rule")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Salary")
        #expect(stored?.notes == "new rule")
    }

    @Test("updating name only leaves the notes unchanged")
    func nameOnlyPreservesNotes() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Old", notes: "keep me")

        try await sut.updateAccount(accountID: account.id, name: "New")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "New")
        #expect(stored?.notes == "keep me")
    }

    @Test("an explicit empty notes string clears the notes")
    func emptyStringClearsNotes() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Acct", notes: "has rules")

        try await sut.updateAccount(accountID: account.id, notes: "")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Acct")
        #expect(stored?.notes == "")
    }

    @Test("is a no-op when neither name nor notes is provided")
    func noOpWhenNothingProvided() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Old", notes: "keep")
        let before = try await sut.accounts.fetch(id: account.id)

        try await sut.updateAccount(accountID: account.id)

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Old")
        #expect(stored?.notes == "keep")
        #expect(stored?.version == before?.version)
    }
}
