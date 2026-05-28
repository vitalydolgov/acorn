import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("GetAccount")
struct GetAccountTests {
    private struct SUT {
        let accounts: InMemoryAccountRepository
        let queries: AccountQueries

        init() {
            let accounts = InMemoryAccountRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts)
            self.accounts = accounts
            self.queries = AccountQueries(unitOfWork: uow)
        }
    }

    @Test("returns the account including its notes")
    func returnsAccount() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "salary only; no transfers out")
        try await sut.accounts.save(account)

        let found = try await sut.queries.get(accountID: account.id)
        #expect(found.id == account.id)
        #expect(found.name == "Checking")
        #expect(found.notes == "salary only; no transfers out")
    }

    @Test("throws notFound when the account does not exist")
    func notFound() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.get(accountID: UUID())
        }
    }

    @Test("throws notFound for a soft-deleted account")
    func deletedIsNotFound() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(account)
        var stored = try #require(try await sut.accounts.fetch(id: account.id))
        try stored.delete()
        try await sut.accounts.save(stored)

        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.get(accountID: account.id)
        }
    }
}
