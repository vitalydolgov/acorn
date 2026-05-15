import Foundation
import AcornDomain
@testable import AcornApplication

final class InMemoryUnitOfWork: UnitOfWork, @unchecked Sendable {
    private let accounts: InMemoryAccountRepository
    private let transactions: InMemoryTransactionRepository
    private let transfers: InMemoryTransferRepository

    init(
        accounts: InMemoryAccountRepository,
        transactions: InMemoryTransactionRepository,
        transfers: InMemoryTransferRepository
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.transfers = transfers
    }

    func perform<T: Sendable>(
        _ body: @Sendable (any RepositoryContext) async throws -> T
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
