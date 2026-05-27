import Foundation
import AcornDomain

public struct ChangeTransactionAmount: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transactionID: UUID, amount: Decimal) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        guard !transaction.isTransferLeg else {
            throw ApplicationError.invalidArgument("cannot edit a transfer leg directly")
        }
        try transaction.update(amount: amount, date: transaction.date)
        try await ctx.transactions.save(transaction)
    }
}
