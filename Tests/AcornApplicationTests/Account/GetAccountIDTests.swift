import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("GetAccountID")
struct GetAccountIDTests {
    private struct SUT {
        let accounts: InMemoryAccountRepository
        let getAccountID: GetAccountID

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions, transfers: transfers)
            self.accounts = accounts
            self.getAccountID = GetAccountID(unitOfWork: uow)
        }
    }

    @Test("returns id on exact-name match")
    func exactMatch() async throws {
        let sut = SUT()
        let checking = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(checking)
        try await sut.accounts.save(try Account.make(name: "Savings", notes: ""))

        let result = try await sut.getAccountID(name: "Checking")
        guard case let .found(id) = result else {
            Issue.record("expected .found")
            return
        }
        #expect(id == checking.id)
    }

    @Test("match is case-insensitive")
    func caseInsensitive() async throws {
        let sut = SUT()
        let checking = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(checking)

        let result = try await sut.getAccountID(name: "checking")
        guard case let .found(id) = result else {
            Issue.record("expected .found")
            return
        }
        #expect(id == checking.id)
    }

    @Test("returns ambiguous when multiple accounts share the name")
    func ambiguous() async throws {
        let sut = SUT()
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))

        let result = try await sut.getAccountID(name: "Checking")
        guard case let .ambiguous(candidates) = result else {
            Issue.record("expected .ambiguous")
            return
        }
        #expect(candidates.count == 2)
    }

    @Test("throws notFound when no account matches")
    func notFound() async throws {
        let sut = SUT()
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.getAccountID(name: "Savings")
        }
    }

    @Test("ignores deleted accounts when matching")
    func ignoresDeleted() async throws {
        let sut = SUT()
        var deleted = try Account.make(name: "Checking", notes: "")
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: ApplicationError.self) {
            _ = try await sut.getAccountID(name: "Checking")
        }
    }

    @Test("rejects blank name")
    func rejectsBlank() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.invalidArgument("name must not be blank")) {
            _ = try await sut.getAccountID(name: "   ")
        }
    }
}
