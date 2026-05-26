import Foundation
import AcornDomain

public struct AddAccount: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(name: String, notes: String = "") async throws -> Account {
        let account = try Account.make(name: name, notes: notes)
        try await ctx.accounts.save(account)
        return account
    }
}
