import Foundation
import AcornDomain
import AcornApplication

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

public final class InMemoryAccountRepository: AccountRepository {
    public var accounts: [UUID: Account] = [:]
    public var saveHook: ((Account) throws -> Void)?

    public init() {}

    public func fetch(id: UUID) async throws -> Account? { accounts[id] }

    public func fetchActive() async throws -> [Account] {
        accounts.values.filter { !$0.isDeleted }
    }

    public func save(_ account: Account) async throws {
        try saveHook?(account)
        try accounts.upsert(account)
    }

    public func delete(id: UUID) async throws { accounts.removeValue(forKey: id) }

    public func put(_ account: Account) { accounts[account.id] = account }
}

public final class InMemoryTransactionRepository: TransactionRepository {
    public var transactions: [UUID: Transaction] = [:]
    public var saveHook: ((Transaction) throws -> Void)?

    public init() {}

    public func fetch(id: UUID) async throws -> Transaction? { transactions[id] }

    public func fetchActive(forAccount accountID: UUID) async throws -> [Transaction] {
        transactions.values.filter { $0.accountID == accountID && !$0.isDeleted }
    }

    public func save(_ transaction: Transaction) async throws {
        try saveHook?(transaction)
        try transactions.upsert(transaction)
    }

    public func delete(id: UUID) async throws { transactions.removeValue(forKey: id) }

    public func put(_ transaction: Transaction) { transactions[transaction.id] = transaction }
}

public final class InMemoryTransferRepository: TransferRepository {
    public var transfers: [UUID: Transfer] = [:]
    public var saveHook: ((Transfer) throws -> Void)?

    public init() {}

    public func fetch(id: UUID) async throws -> Transfer? { transfers[id] }

    public func fetchActive(forAccount accountID: UUID) async throws -> [Transfer] {
        transfers.values.filter {
            ($0.fromAccountID == accountID || $0.toAccountID == accountID) && !$0.isDeleted
        }
    }

    public func save(_ transfer: Transfer) async throws {
        try saveHook?(transfer)
        try transfers.upsert(transfer)
    }

    public func delete(id: UUID) async throws { transfers.removeValue(forKey: id) }

    public func put(_ transfer: Transfer) { transfers[transfer.id] = transfer }
}
