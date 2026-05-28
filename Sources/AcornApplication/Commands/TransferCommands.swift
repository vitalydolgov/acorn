import Foundation
import AcornDomain

/// State-changing operations on transfers — pairs of linked transaction legs that must always be
/// created, edited, and deleted together.
public struct TransferCommands: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    /// Edit a transfer's amount, date, and cleared state. If `details` omits a counterpart account
    /// the transfer is replaced with a plain transaction on `accountID`.
    @UnitOfWork
    public func changeDetails(transferID: UUID, accountID: UUID, details: TransactionDetails) async throws {
        let legs = try await ctx.transactions.fetch(transferID: transferID)
        guard !legs.isEmpty else {
            throw ApplicationError.notFound(transferID)
        }
        for var leg in legs {
            try leg.delete()
            try await ctx.transactions.save(leg)
        }

        guard let counterpartID = details.counterpartAccountID else {
            guard let account = try await ctx.accounts.fetch(id: accountID) else {
                throw ApplicationError.notFound(accountID)
            }
            try account.assertPostable()
            let transaction = Transaction.add(
                accountID: accountID,
                amount: details.amount,
                date: details.date,
                cleared: details.cleared
            )
            try await ctx.transactions.save(transaction)
            return
        }

        let e = details.transferEndpoints(contextAccountID: accountID, counterpartID: counterpartID)
        for id in [e.from, e.to] {
            guard let account = try await ctx.accounts.fetch(id: id) else {
                throw ApplicationError.notFound(id)
            }
            try account.assertPostable()
        }
        let newLegs = try Transaction.transfer(
            fromAccountID: e.from,
            toAccountID: e.to,
            amount: details.magnitude,
            date: details.date,
            clearedAccountID: details.cleared ? accountID : nil
        )
        try await ctx.transactions.save(newLegs.from)
        try await ctx.transactions.save(newLegs.to)
    }

    /// Delete both legs of a transfer together.
    @UnitOfWork
    public func delete(transferID: UUID) async throws {
        let legs = try await ctx.transactions.fetch(transferID: transferID)
        guard !legs.isEmpty else {
            throw ApplicationError.notFound(transferID)
        }
        for var leg in legs {
            try leg.delete()
            try await ctx.transactions.save(leg)
        }
    }

    /// Record a transfer between two distinct open accounts. `amount` must be positive.
    @UnitOfWork
    public func record(
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate,
        clearedAccountID: UUID? = nil
    ) async throws -> (from: Transaction, to: Transaction) {
        for accountID in [fromAccountID, toAccountID] {
            guard let account = try await ctx.accounts.fetch(id: accountID) else {
                throw ApplicationError.notFound(accountID)
            }
            try account.assertPostable()
        }
        let legs = try Transaction.transfer(
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            amount: amount,
            date: date,
            clearedAccountID: clearedAccountID
        )
        try await ctx.transactions.save(legs.from)
        try await ctx.transactions.save(legs.to)
        return legs
    }
}
