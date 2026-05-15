import Foundation
import AcornDomain

public struct ReopenAccount: Sendable {
    private let accountRepository: any AccountRepository

    public init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    public func callAsFunction(accountID: UUID) async throws {
        guard var account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        try account.reopen()
        try await accountRepository.save(account)
    }
}
