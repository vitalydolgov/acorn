import Foundation
import AcornDomain

public struct ReplaceTransferWithTransaction: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(
        transferID: UUID,
        accountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) async throws -> Transaction {
        let legs = try await ctx.transactions.fetch(transferID: transferID)
        guard !legs.isEmpty else {
            throw ApplicationError.notFound(transferID)
        }
        for var leg in legs {
            try leg.delete()
            try await ctx.transactions.save(leg)
        }

        guard let account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.assertPostable()
        let transaction = Transaction.add(accountID: accountID, amount: amount, date: date)
        try await ctx.transactions.save(transaction)
        return transaction
    }
}
