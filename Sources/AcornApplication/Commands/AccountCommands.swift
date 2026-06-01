import Foundation
import AcornDomain

public struct AccountCommands: Sendable {
    private let unitOfWork: any UnitOfWork
    private let todayProvider: any TodayProvider

    public init(unitOfWork: any UnitOfWork, todayProvider: any TodayProvider) {
        self.unitOfWork = unitOfWork
        self.todayProvider = todayProvider
    }

    /// Add a new account.
    ///
    /// - Throws: If the name is blank.
    @UnitOfWork
    public func add(name: String, notes: String = "") async throws -> Account {
        let account = try Account.make(name: name, notes: notes)
        try await ctx.accounts.save(account)
        return account
    }

    /// Post a correcting adjustment transaction dated today to bring the account to a known balance.
    ///
    /// - Throws: If the account doesn't exist, is closed, or the amount is zero.
    @UnitOfWork
    public func adjustBalance(accountID: UUID, amount: Decimal) async throws -> Transaction {
        guard let account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.assertPostable()
        let transaction = try Transaction.adjust(accountID: accountID, amount: amount, date: todayProvider.today())
        try await ctx.transactions.save(transaction)
        return transaction
    }

    /// Rename an account.
    ///
    /// - Throws: If the account doesn't exist or the new name is blank.
    @UnitOfWork
    public func changeName(accountID: UUID, name: String) async throws {
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.update(name: name, notes: account.notes)
        try await ctx.accounts.save(account)
    }

    /// Close an account, zeroing any non-zero balance with an adjustment dated today first.
    ///
    /// - Throws: If the account doesn't exist or is already closed.
    @UnitOfWork
    public func close(accountID: UUID) async throws {
        let today = todayProvider.today()
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        let transactions = try await ctx.transactions.fetchActive(forAccount: accountID)
        let balance = BalanceCalculator.balance(transactions: transactions, accountID: accountID)
        if balance != 0 {
            let zeroing = try Transaction.adjust(accountID: accountID, amount: -balance, date: today)
            try await ctx.transactions.save(zeroing)
        }
        try account.close()
        try await ctx.accounts.save(account)
    }

    /// Permanently delete an account.
    ///
    /// - Throws: If the account doesn't exist or still has active transactions.
    @UnitOfWork
    public func delete(accountID: UUID) async throws {
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        let transactions = try await ctx.transactions.fetchActive(forAccount: accountID)
        guard AccountPolicy.canDelete(accountID: accountID, transactions: transactions) else {
            throw ApplicationError.policyViolation("account cannot be deleted")
        }
        try account.delete()
        try await ctx.accounts.save(account)
    }

    /// Promote all cleared transactions for an account to reconciled.
    ///
    /// - Throws: If the account doesn't exist or is closed.
    @UnitOfWork
    public func reconcile(accountID: UUID) async throws {
        guard let account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.assertPostable()

        let transactions = try await ctx.transactions.fetchActive(forAccount: accountID)
        for var tx in transactions where tx.status == .cleared {
            try tx.reconcile()
            try await ctx.transactions.save(tx)
        }
    }

    /// Reopen a closed account.
    ///
    /// - Throws: If the account doesn't exist or is not closed.
    @UnitOfWork
    public func reopen(accountID: UUID) async throws {
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.reopen()
        try await ctx.accounts.save(account)
    }

    /// Update an account's notes. Pass an empty string to clear.
    ///
    /// - Throws: If the account doesn't exist.
    @UnitOfWork
    public func updateMetadata(accountID: UUID, notes: String) async throws {
        guard var account = try await ctx.accounts.fetch(id: accountID) else {
            throw ApplicationError.notFound(accountID)
        }
        try account.update(name: account.name, notes: notes)
        try await ctx.accounts.save(account)
    }
}
