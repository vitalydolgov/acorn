import Foundation

public protocol AccountRepository {
    func get(id: UUID) async throws -> Account?
    func all() async throws -> [Account]
    func save(_ account: Account) async throws
    func delete(id: UUID) async throws
}
