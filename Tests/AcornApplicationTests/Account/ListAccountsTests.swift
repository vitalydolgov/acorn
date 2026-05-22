import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ListAccounts")
struct ListAccountsTests {
    private struct SUT {
        let accounts: InMemoryAccountRepository
        let listAccounts: ListAccounts

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.accounts = accounts
            self.listAccounts = ListAccounts(unitOfWork: uow)
        }
    }

    @Test("returns empty when there are no accounts")
    func empty() async throws {
        let sut = SUT()
        let result = try await sut.listAccounts()
        #expect(result.isEmpty)
    }

    @Test("returns non-deleted accounts sorted by name")
    func sorted() async throws {
        let sut = SUT()
        try await sut.accounts.save(try Account.make(name: "Savings", notes: ""))
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))
        try await sut.accounts.save(try Account.make(name: "Brokerage", notes: ""))

        let result = try await sut.listAccounts()
        #expect(result.map(\.name) == ["Brokerage", "Checking", "Savings"])
    }

    @Test("excludes deleted accounts")
    func excludesDeleted() async throws {
        let sut = SUT()
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))
        var deleted = try Account.make(name: "Old", notes: "")
        try deleted.delete()
        try await sut.accounts.save(deleted)

        let result = try await sut.listAccounts()
        #expect(result.map(\.name) == ["Checking"])
    }

    @Test("includes closed accounts")
    func includesClosed() async throws {
        let sut = SUT()
        var closed = try Account.make(name: "Closed", notes: "")
        try closed.close()
        try await sut.accounts.save(closed)

        let result = try await sut.listAccounts()
        #expect(result.count == 1)
        #expect(result[0].isClosed == true)
    }
}
