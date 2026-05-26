import Foundation
import AcornDomain

public struct CalculateBalance: Sendable {
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
        guard try await ctx.accounts.fetch(id: accountID) != nil else {
            throw ApplicationError.notFound(accountID)
        }
        let transactions = try await ctx.transactions.fetchActive(forAccount: accountID)
        return Balances(
            cleared: BalanceCalculator.clearedBalance(
                transactions: transactions,
                accountID: accountID
            ),
            uncleared: BalanceCalculator.unclearedBalance(
                transactions: transactions,
                accountID: accountID
            ),
            working: BalanceCalculator.balance(
                transactions: transactions,
                accountID: accountID
            )
        )
    }
}
