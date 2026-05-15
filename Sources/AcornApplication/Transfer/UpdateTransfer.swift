import Foundation
import AcornDomain

public struct UpdateTransfer: Sendable {
    private let transferRepository: any TransferRepository

    public init(transferRepository: any TransferRepository) {
        self.transferRepository = transferRepository
    }

    public func callAsFunction(transferID: UUID, amount: Decimal, date: AcornDate) async throws {
        guard var transfer = try await transferRepository.get(id: transferID) else {
            throw ApplicationError.notFound
        }
        try transfer.update(amount: amount, date: date)
        try await transferRepository.save(transfer)
    }
}
