import Foundation

public enum BalanceCalculator {
    public static func balance(of transactions: some Sequence<Transaction>) -> Decimal {
        var total: Decimal = 0
        for tx in transactions where !tx.isDeleted {
            total += tx.amount
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
