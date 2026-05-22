import Foundation
import AcornDomain
import AcornApplication

public final class InMemoryUnitOfWork: UnitOfWork, @unchecked Sendable {
    public let accounts: InMemoryAccountRepository
    public let transactions: InMemoryTransactionRepository

    public init(
        accounts: InMemoryAccountRepository = InMemoryAccountRepository(),
        transactions: InMemoryTransactionRepository = InMemoryTransactionRepository()
    ) {
        self.accounts = accounts
        self.transactions = transactions
    }

    public func perform<T: Sendable>(
        _ body: (any RepositoryContext) async throws -> T
    ) async throws -> T {
        let accountsSnap = accounts.accounts
        let transactionsSnap = transactions.transactions
        let ctx = Context(accounts: accounts, transactions: transactions)
        do {
            return try await body(ctx)
        } catch {
            accounts.accounts = accountsSnap
            transactions.transactions = transactionsSnap
            throw error
        }
    }

    private struct Context: RepositoryContext {
        let accounts: any AccountRepository
        let transactions: any TransactionRepository
    }
}
