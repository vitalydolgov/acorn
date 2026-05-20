import Foundation

public protocol TransactionRepository {
    func get(id: UUID) async throws -> Transaction?
    func forAccount(_ accountID: UUID) async throws -> [Transaction]
    func save(_ transaction: Transaction) async throws
    func delete(id: UUID) async throws
}
