import Foundation
import AcornDomain
import AcornApplication

public final class InMemoryUnitOfWork: UnitOfWork, @unchecked Sendable {
    public let accounts: InMemoryAccountRepository
    public let transactions: InMemoryTransactionRepository
    public let transfers: InMemoryTransferRepository

    public init(
        accounts: InMemoryAccountRepository = InMemoryAccountRepository(),
        transactions: InMemoryTransactionRepository = InMemoryTransactionRepository(),
        transfers: InMemoryTransferRepository = InMemoryTransferRepository()
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.transfers = transfers
    }

    public func perform<T: Sendable>(
        _ body: (any RepositoryContext) async throws -> T
    ) async throws -> T {
        let accountsSnap = accounts.accounts
        let transactionsSnap = transactions.transactions
        let transfersSnap = transfers.transfers
        let ctx = Context(accounts: accounts, transactions: transactions, transfers: transfers)
        do {
            return try await body(ctx)
        } catch {
            accounts.accounts = accountsSnap
            transactions.transactions = transactionsSnap
            transfers.transfers = transfersSnap
            throw error
        }
    }

    private struct Context: RepositoryContext {
        let accounts: any AccountRepository
        let transactions: any TransactionRepository
        let transfers: any TransferRepository
    }
}
