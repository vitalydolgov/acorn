import Foundation
import AcornDomain

public struct GetBalance: Sendable {
    public struct Balances: Sendable, Equatable {
        public let cleared: Decimal
        public let uncleared: Decimal
        public let working: Decimal

        public init(cleared: Decimal, uncleared: Decimal, working: Decimal) {
            self.cleared = cleared
            self.uncleared = uncleared
            self.working = working
        }
    }

    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID) async throws -> Balances {
        guard try await ctx.accounts.get(id: accountID) != nil else {
            throw ApplicationError.notFound
        }
        let transactions = try await ctx.transactions.forAccount(accountID)
        let transfers = try await ctx.transfers.forAccount(accountID)
        return Balances(
            cleared: BalanceCalculator.clearedBalance(
                transactions: transactions,
                transfers: transfers,
                accountID: accountID
            ),
            uncleared: BalanceCalculator.unclearedBalance(
                transactions: transactions,
                transfers: transfers,
                accountID: accountID
            ),
            working: BalanceCalculator.balance(
                transactions: transactions,
                transfers: transfers,
                accountID: accountID
            )
        )
    }
}
