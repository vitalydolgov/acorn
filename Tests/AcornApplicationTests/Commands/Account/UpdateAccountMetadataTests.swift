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

        // Services
        let addAccount: AddAccount
        let updateAccountMetadata: UpdateAccountMetadata

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts

            // Services
            self.addAccount = AddAccount(unitOfWork: uow)
            self.updateAccountMetadata = UpdateAccountMetadata(unitOfWork: uow)
        }
    }

    @Test("updates notes, preserving name")
    func updatesNotes() async throws {
        let sut = SUT()
        let account = try await sut.addAccount(name: "Salary", notes: "old rule")

        try await sut.updateAccountMetadata(accountID: account.id, notes: "new rule")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Salary")
        #expect(stored?.notes == "new rule")
    }

    @Test("clears notes when given an empty string")
    func clearsNotes() async throws {
        let sut = SUT()
        let account = try await sut.addAccount(name: "Acct", notes: "has rules")

        try await sut.updateAccountMetadata(accountID: account.id, notes: "")

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Acct")
        #expect(stored?.notes == "")
    }

    @Test("fails for unknown account")
    func failsForUnknown() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.updateAccountMetadata(accountID: UUID(), notes: "any")
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = SUT()
        let account = try await sut.addAccount(name: "Old")
        var deleted = try await sut.accounts.fetch(id: account.id)!
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            try await sut.updateAccountMetadata(accountID: account.id, notes: "new")
        }
    }
}
