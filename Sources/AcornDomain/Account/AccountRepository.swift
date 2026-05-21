import Foundation

public protocol AccountRepository {
    func fetch(id: UUID) async throws -> Account?
    func fetchActive() async throws -> [Account]
    func save(_ account: Account) async throws
    func delete(id: UUID) async throws
}
