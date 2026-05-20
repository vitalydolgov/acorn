import Foundation
import AcornDomain

public struct CloseAccount: Sendable {
    private let unitOfWork: any UnitOfWork
    private let todayProvider: any TodayProvider

    public init(unitOfWork: any UnitOfWork, todayProvider: any TodayProvider) {
        self.unitOfWork = unitOfWork
        self.todayProvider = todayProvider
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID) async throws {
        let today = todayProvider.today()
        guard var account = try await ctx.accounts.get(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        let transactions = try await ctx.transactions.forAccount(accountID)
        let transfers = try await ctx.transfers.forAccount(accountID)
        let balance = BalanceCalculator.balance(
            transactions: transactions,
            transfers: transfers,
            accountID: accountID
        )
        if balance != 0 {
            let zeroing = try Transaction.adjust(
                accountID: accountID,
                amount: -balance,
                date: today
            )
            try await ctx.transactions.save(zeroing)
        }
        try account.close()
        try await ctx.accounts.save(account)
    }
}
