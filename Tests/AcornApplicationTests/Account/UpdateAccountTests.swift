import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("UpdateAccount")
struct UpdateAccountTests {
    private struct SUT {
        // Repos
        let accounts: InMemoryAccountRepository

        // Services
        let openAccount: OpenAccount
        let updateAccount: UpdateAccount

        init() {
            let accounts = InMemoryAccountRepository()

            // Repos
            self.accounts = accounts

            // Services
            self.openAccount = OpenAccount(accountRepository: accounts)
            self.updateAccount = UpdateAccount(accountRepository: accounts)
        }
    }

    @Test("updates name and notes")
    func updatesNameAndNotes() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Old", notes: "Old notes")

        try await sut.updateAccount(accountID: account.id, name: "New", notes: "New notes")

        let stored = try await sut.accounts.get(id: account.id)
        #expect(stored?.name == "New")
        #expect(stored?.notes == "New notes")
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.notFound) {
            try await sut.updateAccount(accountID: UUID(), name: "Any", notes: "")
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.openAccount(name: "Old")
        var deleted = try await sut.accounts.get(id: account.id)!
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
        let stored = try await sut.accounts.get(id: account.id)
        #expect(stored?.name == "Old")
    }
}
