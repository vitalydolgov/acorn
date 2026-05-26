import Foundation
import AcornDomain

public struct UpdateAccountMetadata: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID, notes: String) async throws {
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.update(name: account.name, notes: notes)
        try await ctx.accounts.save(account)
    }
}
