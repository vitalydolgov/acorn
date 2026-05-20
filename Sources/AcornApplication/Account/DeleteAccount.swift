import Foundation
import AcornDomain

public struct DeleteAccount: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID) async throws {
        guard var account = try await ctx.accounts.get(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        let transactions = try await ctx.transactions.forAccount(accountID)
        let transfers = try await ctx.transfers.forAccount(accountID)
        if transactions.contains(where: { !$0.isDeleted }) {
            throw ApplicationError.invalidState("account has live transactions")
        }
        if transfers.contains(where: { !$0.isDeleted }) {
            throw ApplicationError.invalidState("account is referenced by live transfers")
        }
        try account.delete()
        try await ctx.accounts.save(account)
    }
}
