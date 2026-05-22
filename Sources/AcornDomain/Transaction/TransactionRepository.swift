import Foundation

public protocol TransactionRepository {
    func fetch(id: UUID) async throws -> Transaction?
    func fetchActive(forAccount accountID: UUID) async throws -> [Transaction]
    func fetch(transferID: UUID) async throws -> [Transaction]
    func save(_ transaction: Transaction) async throws
    func delete(id: UUID) async throws
}
