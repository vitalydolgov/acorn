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
        let getBalance: GetBalance
        let recordTransfer: RecordTransfer
        let clearTransaction: ClearTransaction

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.accounts = accounts
            self.transactions = transactions
            self.getBalance = GetBalance(unitOfWork: uow)
            self.recordTransfer = RecordTransfer(unitOfWork: uow)
            self.clearTransaction = ClearTransaction(unitOfWork: uow)
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

    @Test("applies transfer legs in the correct direction with per-leg status")
    func transfers() async throws {
        let sut = SUT()
        let checking = try Account.make(name: "Checking", notes: "")
        let savings = try Account.make(name: "Savings", notes: "")
        try await sut.accounts.save(checking)
        try await sut.accounts.save(savings)
        let legs = try await sut.recordTransfer(
            fromAccountID: checking.id,
            toAccountID: savings.id,
            amount: 50,
            date: .today()
        )
        try await sut.clearTransaction(transactionID: legs.from.id)

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
