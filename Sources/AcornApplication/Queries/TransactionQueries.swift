import Foundation
import AcornDomain

/// Read-only queries on the Transaction aggregate.
public struct TransactionQueries: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    /// Fetch a single non-deleted transaction by id.
    @UnitOfWork
    public func get(transactionID: UUID) async throws -> Transaction {
        guard let transaction = try await ctx.transactions.fetch(id: transactionID),
              !transaction.isDeleted else {
            throw ApplicationError.notFound(transactionID)
        }
        return transaction
    }

    /// List all active (non-deleted) transactions for an account, sorted by date descending.
    @UnitOfWork
    public func list(accountID: UUID) async throws -> [Transaction] {
        guard try await ctx.accounts.fetch(id: accountID) != nil else {
            throw ApplicationError.notFound(accountID)
        }
        return try await ctx.transactions.fetchActive(forAccount: accountID)
            .sorted { $0.date > $1.date }
    }

    /// Fetch both legs of a transfer by the shared transfer id.
    @UnitOfWork
    public func listTransferLegs(transferID: UUID) async throws -> [Transaction] {
        let legs = try await ctx.transactions.fetch(transferID: transferID)
        guard !legs.isEmpty else {
            throw ApplicationError.notFound(transferID)
        }
        return legs
    }
}
