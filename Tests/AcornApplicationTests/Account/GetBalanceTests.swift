import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("GetBalance")
struct GetBalanceTests {
    private struct SUT {
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository
        let transfers: InMemoryTransferRepository
        let getBalance: GetBalance

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions, transfers: transfers)
            self.accounts = accounts
            self.transactions = transactions
            self.transfers = transfers
            self.getBalance = GetBalance(unitOfWork: uow)
        }
    }

    @Test("returns zero for a new account")
    func zero() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(account)

        let balance = try await sut.getBalance(accountID: account.id)
        #expect(balance == 0)
    }

    @Test("sums non-deleted transactions on the account")
    func sumsTransactions() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(account)
        try await sut.transactions.save(
            Transaction.add(accountID: account.id, amount: 100, date: .today())
        )
        try await sut.transactions.save(
            Transaction.add(accountID: account.id, amount: -30, date: .today())
        )

        let balance = try await sut.getBalance(accountID: account.id)
        #expect(balance == 70)
    }

    @Test("applies transfers in the correct direction")
    func transfers() async throws {
        let sut = SUT()
        let checking = try Account.make(name: "Checking", notes: "")
        let savings = try Account.make(name: "Savings", notes: "")
        try await sut.accounts.save(checking)
        try await sut.accounts.save(savings)
        let transfer = try Transfer.create(
            fromAccountID: checking.id,
            toAccountID: savings.id,
            amount: 50,
            date: .today()
        )
        try await sut.transfers.save(transfer)

        #expect(try await sut.getBalance(accountID: checking.id) == -50)
        #expect(try await sut.getBalance(accountID: savings.id) == 50)
    }

    @Test("throws notFound when the account does not exist")
    func notFound() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.notFound) {
            _ = try await sut.getBalance(accountID: UUID())
        }
    }
}
