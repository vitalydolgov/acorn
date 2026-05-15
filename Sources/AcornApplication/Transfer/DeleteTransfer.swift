import Foundation
import AcornDomain

public struct DeleteTransfer: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transferID: UUID) async throws {
        guard var transfer = try await ctx.transfers.get(id: transferID) else {
            throw ApplicationError.notFound
        }
        try transfer.delete()
        try await ctx.transfers.save(transfer)
    }
}
