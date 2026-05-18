import Foundation

public enum BalanceCalculator {
    public static func balance(
        transactions: some Sequence<Transaction>,
        transfers: some Sequence<Transfer>,
        accountID: UUID
    ) -> Decimal {
        var total: Decimal = 0
        for tx in transactions where !tx.isDeleted && tx.accountID == accountID {
            total += tx.amount
        }
        for transfer in transfers where !transfer.isDeleted {
            if transfer.fromAccountID == accountID {
                total -= transfer.amount
            } else if transfer.toAccountID == accountID {
                total += transfer.amount
            }
        }
        return total
    }

    public static func clearedBalance(of transactions: some Sequence<Transaction>) -> Decimal {
        var total: Decimal = 0
        for tx in transactions where !tx.isDeleted {
            switch tx.status {
            case .cleared, .reconciled: total += tx.amount
            case .uncleared: continue
            }
        }
        return total
    }

    public static func unclearedBalance(of transactions: some Sequence<Transaction>) -> Decimal {
        var total: Decimal = 0
        for tx in transactions where tx.status == .uncleared && !tx.isDeleted {
            total += tx.amount
        }
        return total
    }
}
