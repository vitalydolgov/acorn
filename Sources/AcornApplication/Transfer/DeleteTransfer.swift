import Foundation
import AcornDomain

public struct DeleteTransfer: Sendable {
    private let transferRepository: any TransferRepository

    public init(transferRepository: any TransferRepository) {
        self.transferRepository = transferRepository
    }

    public func callAsFunction(transferID: UUID) async throws {
        guard var transfer = try await transferRepository.get(id: transferID) else {
            throw ApplicationError.notFound
        }
        try transfer.delete()
        try await transferRepository.save(transfer)
    }
}
