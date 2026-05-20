import Foundation

public enum AccountPolicy {
    public static func canDelete(
        accountID: UUID,
        transactions: some Sequence<Transaction>,
        transfers: some Sequence<Transfer>
    ) -> Bool {
        let hasLiveTransfer = transfers.contains { transfer in
            !transfer.isDeleted
                && (transfer.fromAccountID == accountID || transfer.toAccountID == accountID)
        }
        if hasLiveTransfer { return false }
        let balance = BalanceCalculator.balance(
            transactions: transactions,
            transfers: transfers,
            accountID: accountID
        )
        return balance == 0
    }
}
