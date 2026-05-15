import Foundation
import AcornDomain

public struct ClearTransaction: Sendable {
    private let transactionRepository: any TransactionRepository

    public init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    public func callAsFunction(transactionID: UUID) async throws {
        guard var transaction = try await transactionRepository.get(id: transactionID) else {
            throw ApplicationError.notFound
        }
        try transaction.clear()
        try await transactionRepository.save(transaction)
    }
}
