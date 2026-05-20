import Foundation
import AcornDomain

public struct UpdateTransaction: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transactionID: UUID, amount: Decimal, date: AcornDate) async throws {
        guard var transaction = try await ctx.transactions.get(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        try transaction.update(amount: amount, date: date)
        try await ctx.transactions.save(transaction)
    }
}
