import Foundation
import AcornDomain

/// State-changing operations on the Transaction aggregate.
public struct TransactionCommands: Sendable {
    private let unitOfWork: any UnitOfWork
    private let transfers: TransferCommands

    public init(unitOfWork: any UnitOfWork, transfers: TransferCommands) {
        self.unitOfWork = unitOfWork
        self.transfers = transfers
    }

    /// Change a transaction's amount. Rejects transfer legs.
    @UnitOfWork
    public func changeAmount(transactionID: UUID, amount: Decimal) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        guard !transaction.isTransferLeg else {
            throw ApplicationError.invalidArgument("cannot edit a transfer leg directly")
        }
        try transaction.update(amount: amount, date: transaction.date)
        try await ctx.transactions.save(transaction)
    }

    /// Change a transaction's date. Rejects transfer legs.
    @UnitOfWork
    public func changeDate(transactionID: UUID, date: AcornDate) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        guard !transaction.isTransferLeg else {
            throw ApplicationError.invalidArgument("cannot edit a transfer leg directly")
        }
        try transaction.update(amount: transaction.amount, date: date)
        try await ctx.transactions.save(transaction)
    }

    /// Edit a transaction's amount, date, and cleared state. If `details` names a counterpart account
    /// the transaction is replaced with a transfer; rejects transfer legs.
    @UnitOfWork
    public func changeDetails(transactionID: UUID, details: TransactionDetails) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        guard !transaction.isTransferLeg else {
            throw ApplicationError.invalidArgument("cannot edit a transfer leg directly")
        }
        let accountID = transaction.accountID

        guard let counterpartID = details.counterpartAccountID else {
            try transaction.update(amount: details.amount, date: details.date)
            try transaction.setCleared(details.cleared)
            try await ctx.transactions.save(transaction)
            return
        }

        try transaction.delete()
        try await ctx.transactions.save(transaction)

        let e = details.transferEndpoints(contextAccountID: accountID, counterpartID: counterpartID)
        for id in [e.from, e.to] {
            guard let account = try await ctx.accounts.fetch(id: id) else {
                throw ApplicationError.notFound(id)
            }
            try account.assertPostable()
        }
        let legs = try Transaction.transfer(
            fromAccountID: e.from,
            toAccountID: e.to,
            amount: details.magnitude,
            date: details.date,
            clearedAccountID: details.cleared ? accountID : nil
        )
        try await ctx.transactions.save(legs.from)
        try await ctx.transactions.save(legs.to)
    }

    /// Mark a transaction cleared.
    @UnitOfWork
    public func clear(transactionID: UUID) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        try transaction.clear()
        try await ctx.transactions.save(transaction)
    }

    /// Delete a transaction. Rejects transfer legs — use `TransferCommands.delete` instead.
    @UnitOfWork
    public func delete(transactionID: UUID) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        guard !transaction.isTransferLeg else {
            throw ApplicationError.invalidArgument("cannot delete a transfer leg directly; use DeleteTransfer")
        }
        try transaction.delete()
        try await ctx.transactions.save(transaction)
    }

    /// Promote a cleared transaction to reconciled.
    @UnitOfWork
    public func reconcile(transactionID: UUID) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        try transaction.reconcile()
        try await ctx.transactions.save(transaction)
    }

    /// Record a transaction against an open account.
    @UnitOfWork
    public func record(accountID: UUID, amount: Decimal, date: AcornDate, cleared: Bool = false) async throws -> Transaction {
        guard let account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.assertPostable()
        let transaction = Transaction.add(accountID: accountID, amount: amount, date: date, cleared: cleared)
        try await ctx.transactions.save(transaction)
        return transaction
    }

    /// Record a transaction or transfer from a unified details value, dispatching on whether a
    /// counterpart account is present.
    public func recordDetails(accountID: UUID, details: TransactionDetails) async throws {
        if let counterpartID = details.counterpartAccountID {
            let e = details.transferEndpoints(contextAccountID: accountID, counterpartID: counterpartID)
            _ = try await transfers.record(
                fromAccountID: e.from,
                toAccountID: e.to,
                amount: details.magnitude,
                date: details.date,
                clearedAccountID: details.cleared ? accountID : nil
            )
        } else {
            _ = try await record(
                accountID: accountID,
                amount: details.amount,
                date: details.date,
                cleared: details.cleared
            )
        }
    }

    /// Revert a cleared transaction to uncleared.
    @UnitOfWork
    public func unclear(transactionID: UUID) async throws {
        guard var transaction = try await ctx.transactions.fetch(id: transactionID) else {
            throw ApplicationError.notFound(transactionID)
        }
        try transaction.unclear()
        try await ctx.transactions.save(transaction)
    }
}
