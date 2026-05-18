import Foundation
import AcornDomain

public struct GetAccount: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID) async throws -> Account {
        guard let account = try await ctx.accounts.get(id: accountID),
              !account.isDeleted else {
            throw ApplicationError.notFound
        }
        return account
    }
}
