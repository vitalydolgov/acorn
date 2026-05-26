import Foundation
import AcornDomain

public struct RecordTransfer: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) async throws -> (from: Transaction, to: Transaction) {
        for accountID in [fromAccountID, toAccountID] {
            guard let account = try await ctx.accounts.fetch(id: accountID) else {
                throw ApplicationError.notFound(accountID)
            }
            try account.assertPostable()
        }
        let legs = try Transaction.transfer(
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            amount: amount,
            date: date
        )
        try await ctx.transactions.save(legs.from)
        try await ctx.transactions.save(legs.to)
        return legs
    }
}
