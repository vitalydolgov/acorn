import Foundation

public protocol TransferRepository {
    func fetch(id: UUID) async throws -> Transfer?
    func fetchActive(forAccount accountID: UUID) async throws -> [Transfer]
    func save(_ transfer: Transfer) async throws
    func delete(id: UUID) async throws
}
