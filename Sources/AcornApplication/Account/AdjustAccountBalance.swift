import Foundation
import AcornDomain

public struct AdjustAccountBalance: Sendable {
    private let unitOfWork: any UnitOfWork
    private let todayProvider: any TodayProvider

    public init(unitOfWork: any UnitOfWork, todayProvider: any TodayProvider) {
        self.unitOfWork = unitOfWork
        self.todayProvider = todayProvider
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID, amount: Decimal) async throws -> Transaction {
        guard let account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.assertPostable()
        let transaction = try Transaction.adjust(accountID: accountID, amount: amount, date: todayProvider.today())
        try await ctx.transactions.save(transaction)
        return transaction
    }
}
