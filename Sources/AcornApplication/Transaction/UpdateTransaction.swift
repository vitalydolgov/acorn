import Foundation
import AcornDomain

public struct UpdateTransaction: Sendable {
    private let transactionRepository: any TransactionRepository

    public init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    public func callAsFunction(transactionID: UUID, amount: Decimal, date: AcornDate) async throws {
        guard var transaction = try await transactionRepository.get(id: transactionID) else {
            throw ApplicationError.notFound
        }
        try transaction.update(amount: amount, date: date)
        try await transactionRepository.save(transaction)
    }
}
