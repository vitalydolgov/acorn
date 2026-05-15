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
            throw ApplicationError.notFound
        }
        let transactions = try await ctx.transactions.forAccount(accountID)
        let transfers = try await ctx.transfers.forAccount(accountID)
        let hasLiveTransactions = transactions.contains { !$0.isDeleted }
        let hasLiveTransfers = transfers.contains { !$0.isDeleted }
        guard !hasLiveTransactions && !hasLiveTransfers else {
            throw ApplicationError.invalidState
        }
        try account.delete()
        try await ctx.accounts.save(account)
    }
}
