import Foundation
import AcornDomain

public struct UpdateTransfer: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transferID: UUID, amount: Decimal, date: AcornDate) async throws {
        let legs = try await ctx.transactions.fetch(transferID: transferID)
        guard !legs.isEmpty else {
            throw ApplicationError.notFound(transferID)
        }
        for var leg in legs {
            try leg.reviseTransferLeg(amount: amount, date: date)
            try await ctx.transactions.save(leg)
        }
    }
}
