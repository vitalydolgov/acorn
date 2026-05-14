import Foundation
import AcornDomain

// TODO: two-repo writes in `close` are not transactional — a failure between
// the zeroing transaction and the account save leaves inconsistent state.
// Revisit with a unit-of-work.
public struct AccountLifecycle: Sendable {
    private let accountRepository: any AccountRepository
    private let transactionRepository: any TransactionRepository
    private let todayProvider: TodayProvider

    public init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository,
        todayProvider: TodayProvider
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
        self.todayProvider = todayProvider
    }

    public func close(accountID: UUID) async throws {
        guard var account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        let transactions = try await transactionRepository.forAccount(accountID)
        let balance = BalanceCalculator.balance(of: transactions)
        if balance != 0 {
            let zeroing = try Transaction.adjust(
                accountID: accountID,
                amount: -balance,
                date: todayProvider.today()
            )
            try await transactionRepository.save(zeroing)
        }
        try account.close()
        try await accountRepository.save(account)
    }

    public func reopen(accountID: UUID) async throws {
        guard var account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        try account.reopen()
        try await accountRepository.save(account)
    }

    public func delete(accountID: UUID) async throws {
        guard var account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        let transactions = try await transactionRepository.forAccount(accountID)
        let live = transactions.filter { !$0.isDeleted }
        let deletable = live.isEmpty
            || (live.count == 1 && live[0].kind == .starting)
        guard deletable else {
            throw ApplicationError.invalidState
        }
        try account.delete()
        try await accountRepository.save(account)
    }
}
