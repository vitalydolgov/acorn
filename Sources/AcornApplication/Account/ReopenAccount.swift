import Foundation
import AcornDomain

public struct ReopenAccount: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID) async throws {
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.reopen()
        try await ctx.accounts.save(account)
    }
}
