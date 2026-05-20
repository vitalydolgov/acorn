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

    @Test("returns zero balances for a new account")
    func zero() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(account)

        let balances = try await sut.getBalance(accountID: account.id)
        #expect(balances == GetBalance.Balances(cleared: 0, uncleared: 0, working: 0))
    }

    @Test("splits cleared and uncleared transactions and sums the working balance")
    func splitsByStatus() async throws {
        let sut = SUT()
        let account = try Account.make(name: "Checking", notes: "")
        try await sut.accounts.save(account)

        var clearedDeposit = Transaction.add(accountID: account.id, amount: 100, date: .today())
        try clearedDeposit.clear()
        try await sut.transactions.save(clearedDeposit)
        try await sut.transactions.save(
            Transaction.add(accountID: account.id, amount: -30, date: .today())
        )

        let balances = try await sut.getBalance(accountID: account.id)
        #expect(balances.cleared == 100)
        #expect(balances.uncleared == -30)
        #expect(balances.working == 70)
    }

    @Test("applies transfers in the correct direction with per-side status")
    func transfers() async throws {
        let sut = SUT()
        let checking = try Account.make(name: "Checking", notes: "")
        let savings = try Account.make(name: "Savings", notes: "")
        try await sut.accounts.save(checking)
        try await sut.accounts.save(savings)
        var transfer = try Transfer.create(
            fromAccountID: checking.id,
            toAccountID: savings.id,
            amount: 50,
            date: .today()
        )
        try transfer.clear(side: .from)
        try await sut.transfers.save(transfer)

        let checkingBalances = try await sut.getBalance(accountID: checking.id)
        #expect(checkingBalances.cleared == -50)
        #expect(checkingBalances.uncleared == 0)
        #expect(checkingBalances.working == -50)

        let savingsBalances = try await sut.getBalance(accountID: savings.id)
        #expect(savingsBalances.cleared == 0)
        #expect(savingsBalances.uncleared == 50)
        #expect(savingsBalances.working == 50)
    }

    @Test("throws notFound when the account does not exist")
    func notFound() async throws {
        let sut = SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.getBalance(accountID: UUID())
        }
    }
}
