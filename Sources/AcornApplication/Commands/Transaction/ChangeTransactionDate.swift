import Foundation
import AcornDomain

public struct ChangeTransactionDate: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transactionID: UUID, date: AcornDate) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        guard !transaction.isTransferLeg else {
            throw ApplicationError.invalidArgument("cannot edit a transfer leg directly; use ChangeTransferDate")
        }
        try transaction.update(amount: transaction.amount, date: date)
        try await ctx.transactions.save(transaction)
    }
}
