import Foundation
import AcornDomain

public struct UnclearTransaction: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transactionID: UUID) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        try transaction.unclear()
        try await ctx.transactions.save(transaction)
    }
}
