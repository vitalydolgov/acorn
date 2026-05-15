import Foundation
import AcornDomain

public struct OpenAccount: Sendable {
    private let accountRepository: any AccountRepository

    public init(accountRepository: any AccountRepository) {
        self.accountRepository = accountRepository
    }

    public func callAsFunction(name: String, notes: String = "") async throws -> Account {
        let account = try Account.make(name: name, notes: notes)
        try await accountRepository.save(account)
        return account
    }
}
