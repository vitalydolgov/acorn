import Foundation
import AcornDomain

public struct TransactionLifecycle: Sendable {
    private let transactionRepository: any TransactionRepository

    public init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    public func clear(transactionID: UUID) async throws {
        let transaction = try await editable(transactionID)
        guard transaction.status == .uncleared else {
            throw ApplicationError.invalidState
        }
        try await transactionRepository.save(transaction.cleared())
    }

    public func unclear(transactionID: UUID) async throws {
        let transaction = try await editable(transactionID)
        guard transaction.status == .cleared else {
            throw ApplicationError.invalidState
        }
        try await transactionRepository.save(transaction.uncleared())
    }

    public func reconcile(transactionID: UUID) async throws {
        let transaction = try await editable(transactionID)
        guard transaction.status == .cleared else {
            throw ApplicationError.invalidState
        }
        try await transactionRepository.save(transaction.reconciled())
    }

    public func delete(transactionID: UUID) async throws {
        let transaction = try await editable(transactionID)
        try await transactionRepository.save(transaction.deleted())
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
