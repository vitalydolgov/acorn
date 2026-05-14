import Foundation
import AcornDomain

public struct TransactionLifecycle: Sendable {
    private let transactionRepository: any TransactionRepository

    public init(transactionRepository: any TransactionRepository) {
        self.transactionRepository = transactionRepository
    }

    public func clear(transactionID: UUID) async throws {
        var transaction = try await load(transactionID)
        try transaction.clear()
        try await transactionRepository.save(transaction)
    }

    public func unclear(transactionID: UUID) async throws {
        var transaction = try await load(transactionID)
        try transaction.unclear()
        try await transactionRepository.save(transaction)
    }

    public func reconcile(transactionID: UUID) async throws {
        var transaction = try await load(transactionID)
        try transaction.reconcile()
        try await transactionRepository.save(transaction)
    }

    public func delete(transactionID: UUID) async throws {
        var transaction = try await load(transactionID)
        try transaction.delete()
        try await transactionRepository.save(transaction)
    }

    private func load(_ id: UUID) async throws -> Transaction {
        guard let transaction = try await transactionRepository.get(id: id) else {
            throw ApplicationError.notFound
        }
        return transaction
    }
}
