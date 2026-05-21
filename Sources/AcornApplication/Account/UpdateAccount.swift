import Foundation
import AcornDomain

public struct UpdateAccount: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(
        accountID: UUID,
        name: String? = nil,
        notes: String? = nil
    ) async throws {
        guard name != nil || notes != nil else { return }
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.update(
            name: name ?? account.name,
            notes: notes ?? account.notes
        )
        try await ctx.accounts.save(account)
    }
}
