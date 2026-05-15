import Foundation
import AcornDomain

public struct UpdateAccount: Sendable {
    private let accountRepository: any AccountRepository

    public init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    public func callAsFunction(accountID: UUID, name: String, notes: String) async throws {
        guard var account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        try account.update(name: name, notes: notes)
        try await accountRepository.save(account)
    }
}
