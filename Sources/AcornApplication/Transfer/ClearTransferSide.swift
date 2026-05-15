import Foundation
import AcornDomain

public struct ClearTransferSide: Sendable {
    private let transferRepository: any TransferRepository

    public init(transferRepository: any TransferRepository) {
        self.transferRepository = transferRepository
    }

    public func callAsFunction(transferID: UUID, side: TransferSide) async throws {
        guard var transfer = try await transferRepository.get(id: transferID) else {
            throw ApplicationError.notFound
        }
        try transfer.clear(side: side)
        try await transferRepository.save(transfer)
    }
}
