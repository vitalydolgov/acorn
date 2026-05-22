import Foundation

public enum AccountPolicy {
    public static func canDelete(
        accountID: UUID,
        transactions: some Sequence<Transaction>
    ) -> Bool {
        let hasLiveTransferLeg = transactions.contains { tx in
            !tx.isDeleted && tx.accountID == accountID && tx.isTransferLeg
        }
        if hasLiveTransferLeg { return false }
        let balance = BalanceCalculator.balance(
            transactions: transactions,
            accountID: accountID
        )
        return balance == 0
    }
}
