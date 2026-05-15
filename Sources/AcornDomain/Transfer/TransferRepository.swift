import Foundation

public protocol TransferRepository: Sendable {
    func get(id: UUID) async throws -> Transfer?
    func forAccount(_ accountID: UUID) async throws -> [Transfer]
    func save(_ transfer: Transfer) async throws
    func delete(id: UUID) async throws
}
