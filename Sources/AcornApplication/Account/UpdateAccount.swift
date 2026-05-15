import Foundation
import AcornDomain

public struct UpdateAccount: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID, name: String, notes: String) async throws {
        guard var account = try await ctx.accounts.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        try account.update(name: name, notes: notes)
        try await ctx.accounts.save(account)
    }
}
