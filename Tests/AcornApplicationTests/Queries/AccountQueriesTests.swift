import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("AccountQueries")
struct AccountQueriesTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Queries & commands
        let queries: AccountQueries
        let transferCommands: TransferCommands
        let transactionCommands: TransactionCommands

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Queries & commands
            self.queries = AccountQueries(unitOfWork: uow)
            self.transferCommands = TransferCommands(unitOfWork: uow)
            self.transactionCommands = TransactionCommands(unitOfWork: uow)
        }
    }

    // MARK: - calculateBalance

    @Test("returns zero balances for a new account")
    func calculateBalanceZero() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(account)

        let balances = try await sut.queries.calculateBalance(accountID: account.id)
        #expect(balances == AccountQueries.Balances(cleared: 0, uncleared: 0, working: 0))
    }

    @Test("splits cleared and uncleared transactions and sums the working balance")
    func calculateBalanceSplitsByStatus() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(account)

        var clearedDeposit = Transaction.add(accountID: account.id, amount: 100, date: .today())
        try clearedDeposit.clear()
        try await sut.transactions.save(clearedDeposit)
        try await sut.transactions.save(
            Transaction.add(accountID: account.id, amount: -30, date: .today())
        )

        let balances = try await sut.queries.calculateBalance(accountID: account.id)
        #expect(balances.cleared == 100)
        #expect(balances.uncleared == -30)
        #expect(balances.working == 70)
    }

    @Test("applies transfer legs in the correct direction with per-leg status")
    func calculateBalanceTransfers() async throws {
        let sut = SUT()
        let checking = try Account.make(name: "Checking", notes: "")
        let savings = try Account.make(name: "Savings", notes: "")
        try await sut.accounts.save(checking)
        try await sut.accounts.save(savings)
        let legs = try await sut.transferCommands.record(
            fromAccountID: checking.id,
            toAccountID: savings.id,
            amount: 50,
            date: .today()
        )
        try await sut.transactionCommands.clear(transactionID: legs.from.id)

        let checkingBalances = try await sut.queries.calculateBalance(accountID: checking.id)
        #expect(checkingBalances.cleared == -50)
        #expect(checkingBalances.uncleared == 0)
        #expect(checkingBalances.working == -50)

        let savingsBalances = try await sut.queries.calculateBalance(accountID: savings.id)
        #expect(savingsBalances.cleared == 0)
        #expect(savingsBalances.uncleared == 50)
        #expect(savingsBalances.working == 50)
    }

    @Test("throws notFound when the account does not exist")
    func calculateBalanceNotFound() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.calculateBalance(accountID: UUID())
        }
    }

    // MARK: - get

    @Test("returns the account including its notes")
    func getReturnsAccount() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "salary only; no transfers out")
        try await sut.accounts.save(account)

        let found = try await sut.queries.get(accountID: account.id)
        #expect(found.id == account.id)
        #expect(found.name == "Checking")
        #expect(found.notes == "salary only; no transfers out")
    }

    @Test("throws notFound when the account does not exist")
    func getNotFound() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.get(accountID: UUID())
        }
    }

    @Test("throws notFound for a soft-deleted account")
    func getDeletedIsNotFound() async throws {
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

    // MARK: - getID

    @Test("returns id on exact-name match")
    func getIDExactMatch() async throws {
        let sut = SUT()
        let checking = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(checking)
        try await sut.accounts.save(try Account.make(name: "Savings", notes: ""))

        let result = try await sut.queries.getID(name: "Checking")
        guard case let .found(id) = result else {
            Issue.record("expected .found")
            return
        }
        #expect(id == checking.id)
    }

    @Test("match is case-insensitive")
    func getIDCaseInsensitive() async throws {
        let sut = SUT()
        let checking = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(checking)

        let result = try await sut.queries.getID(name: "checking")
        guard case let .found(id) = result else {
            Issue.record("expected .found")
            return
        }
        #expect(id == checking.id)
    }

    @Test("returns ambiguous when multiple accounts share the name")
    func getIDAmbiguous() async throws {
        let sut = SUT()
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))

        let result = try await sut.queries.getID(name: "Checking")
        guard case let .ambiguous(candidates) = result else {
            Issue.record("expected .ambiguous")
            return
        }
        #expect(candidates.count == 2)
    }

    @Test("throws notFound when no account matches")
    func getIDNotFound() async throws {
        let sut = SUT()
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.getID(name: "Savings")
        }
    }

    @Test("ignores deleted accounts when matching")
    func getIDIgnoresDeleted() async throws {
        let sut = SUT()
        var deleted = try Account.make(name: "Checking", notes: "")
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.getID(name: "Checking")
        }
    }

    @Test("rejects blank name")
    func getIDRejectsBlank() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.invalidArgument("name must not be blank")) {
            _ = try await sut.queries.getID(name: "   ")
        }
    }

    // MARK: - list

    @Test("returns empty when there are no accounts")
    func listEmpty() async throws {
        let sut = SUT()
        let result = try await sut.queries.list()
        #expect(result.isEmpty)
    }

    @Test("returns non-deleted accounts sorted by name")
    func listSorted() async throws {
        let sut = SUT()
        try await sut.accounts.save(try Account.make(name: "Savings", notes: ""))
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))
        try await sut.accounts.save(try Account.make(name: "Brokerage", notes: ""))

        let result = try await sut.queries.list()
        #expect(result.map(\.name) == ["Brokerage", "Checking", "Savings"])
    }

    @Test("excludes deleted accounts")
    func listExcludesDeleted() async throws {
        let sut = SUT()
        try await sut.accounts.save(try Account.make(name: "Checking", notes: ""))
        var deleted = try Account.make(name: "Old", notes: "")
        try deleted.delete()
        try await sut.accounts.save(deleted)

        let result = try await sut.queries.list()
        #expect(result.map(\.name) == ["Checking"])
    }

    @Test("includes closed accounts")
    func listIncludesClosed() async throws {
        let sut = SUT()
        var closed = try Account.make(name: "Closed", notes: "")
        try closed.close()
        try await sut.accounts.save(closed)

        let result = try await sut.queries.list()
        #expect(result.count == 1)
        #expect(result[0].isClosed == true)
    }
}
