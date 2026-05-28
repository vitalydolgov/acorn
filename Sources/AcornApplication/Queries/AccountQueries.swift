import Foundation
import AcornDomain

/// Read-only queries on the Account aggregate.
public struct AccountQueries: Sendable {
    /// Cleared, uncleared, and working balances for an account.
    public struct Balances: Sendable, Equatable {
        /// Sum of cleared and reconciled transactions.
        public let cleared: Decimal
        /// Sum of uncleared transactions.
        public let uncleared: Decimal
        /// Sum of all non-deleted transactions; equals `cleared + uncleared`.
        public let working: Decimal

        public init(cleared: Decimal, uncleared: Decimal, working: Decimal) {
            self.cleared = cleared
            self.uncleared = uncleared
            self.working = working
        }
    }

    /// Outcome of a name-to-id lookup.
    public enum IDResult: Sendable {
        /// Exactly one account matched; carries its id.
        case found(UUID)
        /// Multiple accounts share the name; carries all candidates for disambiguation.
        case ambiguous([Account])
    }

    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    /// Calculate an account's cleared, uncleared, and working balances.
    @UnitOfWork
    public func calculateBalance(accountID: UUID) async throws -> Balances {
        guard try await ctx.accounts.fetch(id: accountID) != nil else {
            throw ApplicationError.notFound(accountID)
        }
        let transactions = try await ctx.transactions.fetchActive(forAccount: accountID)
        return Balances(
            cleared: BalanceCalculator.clearedBalance(transactions: transactions, accountID: accountID),
            uncleared: BalanceCalculator.unclearedBalance(transactions: transactions, accountID: accountID),
            working: BalanceCalculator.balance(transactions: transactions, accountID: accountID)
        )
    }

    /// Fetch a single non-deleted account by id.
    @UnitOfWork
    public func get(accountID: UUID) async throws -> Account {
        guard let account = try await ctx.accounts.fetch(id: accountID),
              !account.isDeleted else {
            throw ApplicationError.notFound(accountID)
        }
        return account
    }

    /// Resolve an account name to its id (case-insensitive). Returns `.ambiguous` when multiple
    /// accounts share the name.
    @UnitOfWork
    public func getID(name: String) async throws -> IDResult {
        guard let normalized = AccountValidation.normalizedName(name) else {
            throw ApplicationError.invalidArgument("name must not be blank")
        }
        let needle = normalized.lowercased()
        let matches = try await ctx.accounts.fetchActive()
            .filter { $0.name.lowercased() == needle }
        switch matches.count {
        case 0:
            throw ApplicationError.notFound(name: normalized)
        case 1:
            return .found(matches[0].id)
        default:
            return .ambiguous(matches.sorted { $0.name < $1.name })
        }
    }

    /// List all non-deleted accounts sorted by name.
    @UnitOfWork
    public func list() async throws -> [Account] {
        try await ctx.accounts.fetchActive()
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
