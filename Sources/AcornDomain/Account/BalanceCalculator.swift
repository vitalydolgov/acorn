import Foundation

public enum BalanceCalculator {
    public static func balance(
        transactions: some Sequence<Transaction>,
        transfers: some Sequence<Transfer>,
        accountID: UUID
    ) -> Decimal {
        sum(
            transactions: transactions,
            transfers: transfers,
            accountID: accountID,
            includes: { _ in true }
        )
    }

    public static func clearedBalance(
        transactions: some Sequence<Transaction>,
        transfers: some Sequence<Transfer>,
        accountID: UUID
    ) -> Decimal {
        sum(
            transactions: transactions,
            transfers: transfers,
            accountID: accountID,
            includes: { $0 != .uncleared }
        )
    }

    public static func unclearedBalance(
        transactions: some Sequence<Transaction>,
        transfers: some Sequence<Transfer>,
        accountID: UUID
    ) -> Decimal {
        sum(
            transactions: transactions,
            transfers: transfers,
            accountID: accountID,
            includes: { $0 == .uncleared }
        )
    }

    private static func sum(
        transactions: some Sequence<Transaction>,
        transfers: some Sequence<Transfer>,
        accountID: UUID,
        includes: (TransactionStatus) -> Bool
    ) -> Decimal {
        var total: Decimal = 0
        for tx in transactions where !tx.isDeleted && tx.accountID == accountID {
            if includes(tx.status) { total += tx.amount }
        }
        for transfer in transfers where !transfer.isDeleted {
            if transfer.fromAccountID == accountID, includes(transfer.fromStatus) {
                total -= transfer.amount
            } else if transfer.toAccountID == accountID, includes(transfer.toStatus) {
                total += transfer.amount
            }
        }
        return total
    }
}
