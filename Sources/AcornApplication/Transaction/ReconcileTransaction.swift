import Foundation
import AcornDomain

public struct ReconcileTransaction: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transactionID: UUID) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        try transaction.reconcile()
        try await ctx.transactions.save(transaction)
    }
}
