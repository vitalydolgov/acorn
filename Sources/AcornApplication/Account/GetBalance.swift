import Foundation
import AcornDomain

public struct GetBalance: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID) async throws -> Decimal {
        guard try await ctx.accounts.get(id: accountID) != nil else {
            throw ApplicationError.notFound
        }
        let transactions = try await ctx.transactions.forAccount(accountID)
        let transfers = try await ctx.transfers.forAccount(accountID)
        return BalanceCalculator.balance(
            transactions: transactions,
            transfers: transfers,
            accountID: accountID
        )
    }
}
