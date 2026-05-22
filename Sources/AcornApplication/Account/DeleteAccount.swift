import Foundation
import AcornDomain

public struct DeleteAccount: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID) async throws {
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        let transactions = try await ctx.transactions.fetchActive(forAccount: accountID)
        guard AccountPolicy.canDelete(
            accountID: accountID,
            transactions: transactions
        ) else {
            throw ApplicationError.policyViolation("account cannot be deleted")
        }
        try account.delete()
        try await ctx.accounts.save(account)
    }
}
