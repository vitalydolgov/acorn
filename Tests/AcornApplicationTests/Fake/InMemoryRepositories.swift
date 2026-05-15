import Foundation
import AcornDomain
@testable import AcornApplication

extension Dictionary where Key == UUID, Value: Versioned {
    mutating func upsert(_ value: Value) throws {
        guard (self[value.id]?.version ?? 0) == value.version else {
            throw DomainError.conflict
        }
        var persisted = value
        persisted.version += 1
        self[value.id] = persisted
    }
}


final class InMemoryAccountRepository: AccountRepository, @unchecked Sendable {
    var accounts: [UUID: Account] = [:]
    var saveHook: ((Account) throws -> Void)?

    func get(id: UUID) async throws -> Account? { accounts[id] }
    func all() async throws -> [Account] { Array(accounts.values) }
    func save(_ account: Account) async throws {
        try saveHook?(account)
        try accounts.upsert(account)
    }
    func delete(id: UUID) async throws { accounts.removeValue(forKey: id) }
}

final class InMemoryTransactionRepository: TransactionRepository, @unchecked Sendable {
    var transactions: [UUID: Transaction] = [:]
    var saveHook: ((Transaction) throws -> Void)?

    func get(id: UUID) async throws -> Transaction? { transactions[id] }
    func forAccount(_ accountID: UUID) async throws -> [Transaction] {
        transactions.values.filter { $0.accountID == accountID }
    }
    func save(_ transaction: Transaction) async throws {
        try saveHook?(transaction)
        try transactions.upsert(transaction)
    }
    func delete(id: UUID) async throws { transactions.removeValue(forKey: id) }
}

final class InMemoryTransferRepository: TransferRepository, @unchecked Sendable {
    var transfers: [UUID: Transfer] = [:]
    var saveHook: ((Transfer) throws -> Void)?

    func get(id: UUID) async throws -> Transfer? { transfers[id] }
    func forAccount(_ accountID: UUID) async throws -> [Transfer] {
        transfers.values.filter { $0.fromAccountID == accountID || $0.toAccountID == accountID }
    }
    func save(_ transfer: Transfer) async throws {
        try saveHook?(transfer)
        try transfers.upsert(transfer)
    }
    func delete(id: UUID) async throws { transfers.removeValue(forKey: id) }
}
