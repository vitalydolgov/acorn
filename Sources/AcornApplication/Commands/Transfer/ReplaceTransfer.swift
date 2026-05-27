import Foundation
import AcornDomain

public struct ReplaceTransfer: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(
        transferID: UUID,
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) async throws -> (from: Transaction, to: Transaction) {
        let legs = try await ctx.transactions.fetch(transferID: transferID)
        guard !legs.isEmpty else {
            throw ApplicationError.notFound(transferID)
        }
        for var leg in legs {
            try leg.delete()
            try await ctx.transactions.save(leg)
        }

        for accountID in [fromAccountID, toAccountID] {
            guard let account = try await ctx.accounts.fetch(id: accountID) else {
                throw ApplicationError.notFound(accountID)
            }
            try account.assertPostable()
        }
        let newLegs = try Transaction.transfer(fromAccountID: fromAccountID, toAccountID: toAccountID, amount: amount, date: date)
        try await ctx.transactions.save(newLegs.from)
        try await ctx.transactions.save(newLegs.to)
        return newLegs
    }
}
