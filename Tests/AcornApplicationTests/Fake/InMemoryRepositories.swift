import Foundation
import AcornDomain

final class InMemoryAccountRepository: AccountRepository, @unchecked Sendable {
    private var accounts: [UUID: Account] = [:]

    func get(id: UUID) async throws -> Account? { accounts[id] }
    func all() async throws -> [Account] { Array(accounts.values) }
    func save(_ account: Account) async throws { accounts[account.id] = account }
    func delete(id: UUID) async throws { accounts.removeValue(forKey: id) }
}

final class InMemoryTransactionRepository: TransactionRepository, @unchecked Sendable {
    private var transactions: [UUID: Transaction] = [:]

    func get(id: UUID) async throws -> Transaction? { transactions[id] }
    func forAccount(_ accountID: UUID) async throws -> [Transaction] {
        transactions.values.filter { $0.accountID == accountID }
    }
    func save(_ transaction: Transaction) async throws { transactions[transaction.id] = transaction }
    func delete(id: UUID) async throws { transactions.removeValue(forKey: id) }
}