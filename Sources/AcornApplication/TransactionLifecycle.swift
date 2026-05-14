import Foundation
import AcornDomain

public struct TransactionLifecycle: Sendable {
    private let transactionRepository: any TransactionRepository

    public init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    public func clear(transactionID: UUID) async throws {
        var transaction = try await editable(transactionID)
        guard transaction.status == .uncleared else {
            throw ApplicationError.invalidState
        }
        transaction.clear()
        try await transactionRepository.save(transaction)
    }

    public func unclear(transactionID: UUID) async throws {
        var transaction = try await editable(transactionID)
        guard transaction.status == .cleared else {
            throw ApplicationError.invalidState
        }
        transaction.unclear()
        try await transactionRepository.save(transaction)
    }

    public func reconcile(transactionID: UUID) async throws {
        var transaction = try await editable(transactionID)
        guard transaction.status == .cleared else {
            throw ApplicationError.invalidState
        }
        transaction.reconcile()
        try await transactionRepository.save(transaction)
    }

    public func delete(transactionID: UUID) async throws {
        var transaction = try await editable(transactionID)
        transaction.delete()
        try await transactionRepository.save(transaction)
    }

    private func editable(_ id: UUID) async throws -> Transaction {
        guard let transaction = try await transactionRepository.get(id: id) else {
            throw ApplicationError.notFound
        }
        guard !transaction.isDeleted else {
            throw ApplicationError.invalidState
        }
        return transaction
    }
}
