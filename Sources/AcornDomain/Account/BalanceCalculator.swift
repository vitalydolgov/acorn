import Foundation

public enum BalanceCalculator {
    public static func balance(
        transactions: some Sequence<Transaction>,
        accountID: UUID
    ) -> Decimal {
        sum(
            transactions: transactions,
            accountID: accountID,
            includes: { _ in true }
        )
    }

    public static func clearedBalance(
        transactions: some Sequence<Transaction>,
        accountID: UUID
    ) -> Decimal {
        sum(
            transactions: transactions,
            accountID: accountID,
            includes: { $0 != .uncleared }
        )
    }

    public static func unclearedBalance(
        transactions: some Sequence<Transaction>,
        accountID: UUID
    ) -> Decimal {
        sum(
            transactions: transactions,
            accountID: accountID,
            includes: { $0 == .uncleared }
        )
    }

    private static func sum(
        transactions: some Sequence<Transaction>,
        accountID: UUID,
        includes: (TransactionStatus) -> Bool
    ) -> Decimal {
        var total: Decimal = 0
        for tx in transactions where !tx.isDeleted && tx.accountID == accountID {
            if includes(tx.status) { total += tx.amount }
        }
        return total
    }
}
