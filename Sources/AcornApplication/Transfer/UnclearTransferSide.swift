import Foundation
import AcornDomain

public struct UnclearTransferSide: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transferID: UUID, side: TransferSide) async throws {
        guard var transfer = try await ctx.transfers.fetch(id: transferID) else {
            throw ApplicationError.notFound(transferID)
        }
        try transfer.unclear(side: side)
        try await ctx.transfers.save(transfer)
    }
}
