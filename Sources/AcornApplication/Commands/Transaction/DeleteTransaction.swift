import Foundation
import AcornDomain

public struct DeleteTransaction: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transactionID: UUID) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        guard !transaction.isTransferLeg else {
            throw ApplicationError.invalidArgument("cannot delete a transfer leg directly; use DeleteTransfer")
        }
        try transaction.delete()
        try await ctx.transactions.save(transaction)
    }
}
