import Foundation
import AcornDomain

public struct ClearTransferSide: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(transferID: UUID, side: TransferSide) async throws {
        guard var transfer = try await ctx.transfers.get(id: transferID) else {
            throw ApplicationError.notFound
        }
        try transfer.clear(side: side)
        try await ctx.transfers.save(transfer)
    }
}
