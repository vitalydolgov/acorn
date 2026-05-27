import Foundation
import AcornDomain

public struct ReplaceTransactionWithTransfer: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(
        transactionID: UUID,
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) async throws -> (from: Transaction, to: Transaction) {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        guard !transaction.isTransferLeg else {
            throw ApplicationError.invalidArgument("cannot replace a transfer leg directly; use ReplaceTransfer")
        }
        try transaction.delete()
        try await ctx.transactions.save(transaction)

        for accountID in [fromAccountID, toAccountID] {
            guard let account = try await ctx.accounts.fetch(id: accountID) else {
                throw ApplicationError.notFound(accountID)
            }
            try account.assertPostable()
        }
        let legs = try Transaction.transfer(fromAccountID: fromAccountID, toAccountID: toAccountID, amount: amount, date: date)
        try await ctx.transactions.save(legs.from)
        try await ctx.transactions.save(legs.to)
        return legs
    }
}
