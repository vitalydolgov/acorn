import Foundation
import Testing
@testable import AcornDomain

@Suite("BalanceCalculator")
struct BalanceCalculatorTests {
    private let accountID = UUID()
    private let other = UUID()
    private let today = AcornDate.today()

    private func deposit(_ amount: Decimal) -> Transaction {
        Transaction.add(accountID: accountID, amount: amount, date: today)
    }

    private func withdraw(_ amount: Decimal) -> Transaction {
        Transaction.add(accountID: accountID, amount: -amount, date: today)
    }

    private func cleared(_ tx: Transaction) throws -> Transaction {
        var tx = tx
        try tx.clear()
        return tx
    }

    private func reconciled(_ tx: Transaction) throws -> Transaction {
        var tx = tx
        try tx.clear()
        try tx.reconcile()
        return tx
    }

    private func clearedSide(_ transfer: Transfer, _ side: TransferSide) throws -> Transfer {
        var transfer = transfer
        try transfer.clear(side: side)
        return transfer
    }

    // MARK: - balance

    @Test("balance sums all non-deleted transactions regardless of status")
    func balanceSumsAllNonDeleted() throws {
        let txs = [
            deposit(100),
            try cleared(deposit(50)),
            try reconciled(deposit(25)),
            withdraw(30),
        ]
        #expect(
            BalanceCalculator.balance(
                transactions: txs,
                transfers: [Transfer](),
                accountID: accountID
            ) == 145
        )
    }

    @Test("balance skips deleted transactions")
    func balanceSkipsDeleted() throws {
        var deletedDeposit = deposit(999)
        try deletedDeposit.delete()
        let txs = [
            deposit(100),
            deletedDeposit,
        ]
        #expect(
            BalanceCalculator.balance(
                transactions: txs,
                transfers: [Transfer](),
                accountID: accountID
            ) == 100
        )
    }

    @Test("balance of empty sequence is zero")
    func balanceOfEmptyIsZero() {
        #expect(
            BalanceCalculator.balance(
                transactions: [Transaction](),
                transfers: [Transfer](),
                accountID: accountID
            ) == 0
        )
    }

    @Test("balance filters transactions by accountID")
    func balanceFiltersByAccount() {
        let foreign = Transaction.add(accountID: other, amount: 500, date: today)
        let txs = [deposit(100), foreign]
        #expect(
            BalanceCalculator.balance(
                transactions: txs,
                transfers: [Transfer](),
                accountID: accountID
            ) == 100
        )
    }

    @Test("balance subtracts outgoing transfers and adds incoming")
    func balanceAppliesTransferLegs() throws {
        let outgoing = try Transfer.create(
            fromAccountID: accountID,
            toAccountID: other,
            amount: 30,
            date: today
        )
        let incoming = try Transfer.create(
            fromAccountID: other,
            toAccountID: accountID,
            amount: 10,
            date: today
        )
        #expect(
            BalanceCalculator.balance(
                transactions: [deposit(100)],
                transfers: [outgoing, incoming],
                accountID: accountID
            ) == 80
        )
    }

    @Test("balance skips deleted transfers")
    func balanceSkipsDeletedTransfers() throws {
        var deletedTransfer = try Transfer.create(
            fromAccountID: accountID,
            toAccountID: other,
            amount: 30,
            date: today
        )
        try deletedTransfer.delete()
        #expect(
            BalanceCalculator.balance(
                transactions: [deposit(100)],
                transfers: [deletedTransfer],
                accountID: accountID
            ) == 100
        )
    }

    @Test("balance ignores transfers that do not involve the account")
    func balanceIgnoresUnrelatedTransfers() throws {
        let a = UUID(), b = UUID()
        let unrelated = try Transfer.create(fromAccountID: a, toAccountID: b, amount: 50, date: today)
        #expect(
            BalanceCalculator.balance(
                transactions: [deposit(100)],
                transfers: [unrelated],
                accountID: accountID
            ) == 100
        )
    }

    // MARK: - clearedBalance

    @Test("clearedBalance includes cleared and reconciled, excludes uncleared")
    func clearedBalanceIncludesClearedAndReconciled() throws {
        let txs = [
            deposit(100),
            try cleared(deposit(50)),
            try reconciled(deposit(25)),
        ]
        #expect(
            BalanceCalculator.clearedBalance(
                transactions: txs,
                transfers: [Transfer](),
                accountID: accountID
            ) == 75
        )
    }

    @Test("clearedBalance skips deleted transactions")
    func clearedBalanceSkipsDeleted() throws {
        var deletedClearedDeposit = try cleared(deposit(999))
        try deletedClearedDeposit.delete()
        let txs = [
            try cleared(deposit(50)),
            deletedClearedDeposit,
        ]
        #expect(
            BalanceCalculator.clearedBalance(
                transactions: txs,
                transfers: [Transfer](),
                accountID: accountID
            ) == 50
        )
    }

    @Test("clearedBalance counts only transfer sides that are cleared")
    func clearedBalanceAppliesClearedTransferSides() throws {
        let clearedOut = try clearedSide(
            try Transfer.create(fromAccountID: accountID, toAccountID: other, amount: 30, date: today),
            .from
        )
        let unclearedIn = try Transfer.create(
            fromAccountID: other,
            toAccountID: accountID,
            amount: 10,
            date: today
        )
        #expect(
            BalanceCalculator.clearedBalance(
                transactions: [try cleared(deposit(100))],
                transfers: [clearedOut, unclearedIn],
                accountID: accountID
            ) == 70
        )
    }

    // MARK: - unclearedBalance

    @Test("unclearedBalance only counts uncleared transactions")
    func unclearedBalanceOnlyUncleared() throws {
        let txs = [
            deposit(100),
            try cleared(deposit(50)),
            try reconciled(deposit(25)),
            withdraw(40),
        ]
        #expect(
            BalanceCalculator.unclearedBalance(
                transactions: txs,
                transfers: [Transfer](),
                accountID: accountID
            ) == 60
        )
    }

    @Test("unclearedBalance skips deleted transactions")
    func unclearedBalanceSkipsDeleted() throws {
        var deletedDeposit = deposit(999)
        try deletedDeposit.delete()
        let txs = [
            deposit(100),
            deletedDeposit,
        ]
        #expect(
            BalanceCalculator.unclearedBalance(
                transactions: txs,
                transfers: [Transfer](),
                accountID: accountID
            ) == 100
        )
    }

    @Test("unclearedBalance counts only transfer sides that are uncleared")
    func unclearedBalanceAppliesUnclearedTransferSides() throws {
        let clearedOut = try clearedSide(
            try Transfer.create(fromAccountID: accountID, toAccountID: other, amount: 30, date: today),
            .from
        )
        let unclearedIn = try Transfer.create(
            fromAccountID: other,
            toAccountID: accountID,
            amount: 10,
            date: today
        )
        #expect(
            BalanceCalculator.unclearedBalance(
                transactions: [deposit(100)],
                transfers: [clearedOut, unclearedIn],
                accountID: accountID
            ) == 110
        )
    }

    // MARK: - invariant

    @Test("cleared + uncleared equals total balance, including transfers")
    func clearedPlusUnclearedEqualsBalance() throws {
        var deletedDeposit = deposit(999)
        try deletedDeposit.delete()
        let txs = [
            deposit(100),
            try cleared(deposit(50)),
            try reconciled(deposit(25)),
            withdraw(30),
            deletedDeposit,
        ]
        let transfers = [
            try clearedSide(
                try Transfer.create(fromAccountID: accountID, toAccountID: other, amount: 30, date: today),
                .from
            ),
            try Transfer.create(fromAccountID: other, toAccountID: accountID, amount: 10, date: today),
        ]
        let total = BalanceCalculator.balance(
            transactions: txs,
            transfers: transfers,
            accountID: accountID
        )
        let cleared = BalanceCalculator.clearedBalance(
            transactions: txs,
            transfers: transfers,
            accountID: accountID
        )
        let uncleared = BalanceCalculator.unclearedBalance(
            transactions: txs,
            transfers: transfers,
            accountID: accountID
        )
        #expect(cleared + uncleared == total)
    }
}
