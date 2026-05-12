import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("AccountCreateUpdate")
struct AccountCreateUpdateTests {
    private struct SUT {
        let createUpdate: AccountCreateUpdate
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        init(today: AcornDate = .today()) {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            self.accounts = accounts
            self.transactions = transactions
            self.createUpdate = AccountCreateUpdate(
                accountRepository: accounts,
                transactionRepository: transactions,
                todayProvider: FixedTodayProvider(date: today)
            )
        }
    }

    private static let today = AcornDate.today()

    // MARK: - Create

    @Test("opens an account with name and notes")
    func opensWithNameAndNotes() async throws {
        let sut = SUT()

        let account = try await sut.createUpdate.open(name: "Checking", notes: "Primary", openingBalance: 0)

        #expect(account.name == "Checking")
        #expect(account.notes == "Primary")
        #expect(account.isClosed == false)

        let stored = try await sut.accounts.get(id: account.id)
        #expect(stored?.name == "Checking")
        #expect(stored?.notes == "Primary")
    }

    @Test("rejects empty name")
    func rejectsEmptyName() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.invalidArgument) {
            _ = try await sut.createUpdate.open(name: "   ", openingBalance: 0)
        }
        #expect(try await sut.accounts.all().isEmpty)
    }

    @Test("non-zero opening balance creates a starting transaction")
    func openingBalanceCreatesStartingTransaction() async throws {
        let sut = SUT(today: Self.today)

        let account = try await sut.createUpdate.open(name: "Savings", openingBalance: 100)

        let txs = try await sut.transactions.forAccount(account.id)
        #expect(txs.count == 1)
        let opening = try #require(txs.first)
        #expect(opening.amount == 100)
        #expect(opening.kind == .starting)
        #expect(opening.status == .cleared)
        #expect(opening.date == Self.today)
    }

    // MARK: - Update

    @Test("updates name and notes")
    func updatesNameAndNotes() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "Old", notes: "Old notes", openingBalance: 0)

        try await sut.createUpdate.update(accountID: account.id, name: "New", notes: "New notes")

        let stored = try await sut.accounts.get(id: account.id)
        #expect(stored?.name == "New")
        #expect(stored?.notes == "New notes")
    }

    @Test("update fails for unknown account")
    func updateFailsForUnknownAccount() async throws {
        let sut = SUT()

        await #expect(throws: ApplicationError.notFound) {
            try await sut.createUpdate.update(accountID: UUID(), name: "Any", notes: "")
        }
    }

    @Test("update fails on a deleted account")
    func updateFailsOnDeletedAccount() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "Old", openingBalance: 0)
        try await sut.accounts.save(account.deleted())

        await #expect(throws: ApplicationError.invalidState) {
            try await sut.createUpdate.update(accountID: account.id, name: "New", notes: "")
        }
    }

    @Test("update rejects empty name")
    func updateRejectsEmptyName() async throws {
        let sut = SUT()
        let account = try await sut.createUpdate.open(name: "Old", openingBalance: 0)

        await #expect(throws: ApplicationError.invalidArgument) {
            try await sut.createUpdate.update(accountID: account.id, name: "   ", notes: "")
        }
        let stored = try await sut.accounts.get(id: account.id)
        #expect(stored?.name == "Old")
    }
}
