import Foundation
import AcornDomain
@testable import AcornApplication

struct InjectedFailure: Error, Equatable {}

final class InMemoryAccountRepository: AccountRepository, @unchecked Sendable {
    fileprivate var accounts: [UUID: Account] = [:]
    var failNextSave = false

    func get(id: UUID) async throws -> Account? { accounts[id] }
    func all() async throws -> [Account] { Array(accounts.values) }
    func save(_ account: Account) async throws {
        if failNextSave {
            failNextSave = false
            throw InjectedFailure()
        }
        accounts[account.id] = account
    }
    func delete(id: UUID) async throws { accounts.removeValue(forKey: id) }
}

final class InMemoryTransactionRepository: TransactionRepository, @unchecked Sendable {
    fileprivate var transactions: [UUID: Transaction] = [:]

    func get(id: UUID) async throws -> Transaction? { transactions[id] }
    func forAccount(_ accountID: UUID) async throws -> [Transaction] {
        transactions.values.filter { $0.accountID == accountID }
    }
    func save(_ transaction: Transaction) async throws { transactions[transaction.id] = transaction }
    func delete(id: UUID) async throws { transactions.removeValue(forKey: id) }
}

final class InMemoryTransferRepository: TransferRepository, @unchecked Sendable {
    fileprivate var transfers: [UUID: Transfer] = [:]

    func get(id: UUID) async throws -> Transfer? { transfers[id] }
    func forAccount(_ accountID: UUID) async throws -> [Transfer] {
        transfers.values.filter { $0.fromAccountID == accountID || $0.toAccountID == accountID }
    }
    func save(_ transfer: Transfer) async throws { transfers[transfer.id] = transfer }
    func delete(id: UUID) async throws { transfers.removeValue(forKey: id) }
}

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
