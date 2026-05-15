import Foundation
import Testing
@testable import AcornDomain

@Suite("BalanceCalculator")
struct BalanceCalculatorTests {
    private let accountID = UUID()
    private let today = AcornDate.today()

    private func deposit(_ amount: Decimal) -> Transaction {
        Transaction.post(accountID: accountID, amount: amount, date: today)
    }

    private func withdraw(_ amount: Decimal) -> Transaction {
        Transaction.post(accountID: accountID, amount: -amount, date: today)
    }

    // MARK: - balance

    @Test("balance sums all non-deleted transactions regardless of status")
    func balanceSumsAllNonDeleted() throws {
        var clearedDeposit = deposit(50)
        try clearedDeposit.clear()
        var reconciledDeposit = deposit(25)
        try reconciledDeposit.clear()
        try reconciledDeposit.reconcile()
        let txs = [
            deposit(100),
            clearedDeposit,
            reconciledDeposit,
            withdraw(30),
        ]
        #expect(BalanceCalculator.balance(of: txs) == 145)
    }

    @Test("balance skips deleted transactions")
    func balanceSkipsDeleted() throws {
        var deletedDeposit = deposit(999)
        try deletedDeposit.delete()
        let txs = [
            deposit(100),
            deletedDeposit,
        ]
        #expect(BalanceCalculator.balance(of: txs) == 100)
    }

    @Test("balance of empty sequence is zero")
    func balanceOfEmptyIsZero() {
        #expect(BalanceCalculator.balance(of: [Transaction]()) == 0)
    }

    // MARK: - clearedBalance

    @Test("clearedBalance includes cleared and reconciled, excludes uncleared")
    func clearedBalanceIncludesClearedAndReconciled() throws {
        var clearedDeposit = deposit(50)
        try clearedDeposit.clear()
        var reconciledDeposit = deposit(25)
        try reconciledDeposit.clear()
        try reconciledDeposit.reconcile()
        let txs = [
            deposit(100),
            clearedDeposit,
            reconciledDeposit,
        ]
        #expect(BalanceCalculator.clearedBalance(of: txs) == 75)
    }

    @Test("clearedBalance skips deleted transactions")
    func clearedBalanceSkipsDeleted() throws {
        var clearedDeposit = deposit(50)
        try clearedDeposit.clear()
        var deletedClearedDeposit = deposit(999)
        try deletedClearedDeposit.clear()
        try deletedClearedDeposit.delete()
        let txs = [
            clearedDeposit,
            deletedClearedDeposit,
        ]
        #expect(BalanceCalculator.clearedBalance(of: txs) == 50)
    }

    // MARK: - unclearedBalance

    @Test("unclearedBalance only counts uncleared transactions")
    func unclearedBalanceOnlyUncleared() throws {
        var clearedDeposit = deposit(50)
        try clearedDeposit.clear()
        var reconciledDeposit = deposit(25)
        try reconciledDeposit.clear()
        try reconciledDeposit.reconcile()
        let txs = [
            deposit(100),
            clearedDeposit,
            reconciledDeposit,
            withdraw(40),
        ]
        #expect(BalanceCalculator.unclearedBalance(of: txs) == 60)
    }

    @Test("unclearedBalance skips deleted transactions")
    func unclearedBalanceSkipsDeleted() throws {
        var deletedDeposit = deposit(999)
        try deletedDeposit.delete()
        let txs = [
            deposit(100),
            deletedDeposit,
        ]
        #expect(BalanceCalculator.unclearedBalance(of: txs) == 100)
    }

    @Test("cleared + uncleared equals total balance")
    func clearedPlusUnclearedEqualsBalance() throws {
        var clearedDeposit = deposit(50)
        try clearedDeposit.clear()
        var reconciledDeposit = deposit(25)
        try reconciledDeposit.clear()
        try reconciledDeposit.reconcile()
        var deletedDeposit = deposit(999)
        try deletedDeposit.delete()
        let txs = [
            deposit(100),
            clearedDeposit,
            reconciledDeposit,
            withdraw(30),
            deletedDeposit,
        ]
        let total = BalanceCalculator.balance(of: txs)
        let cleared = BalanceCalculator.clearedBalance(of: txs)
        let uncleared = BalanceCalculator.unclearedBalance(of: txs)
        #expect(cleared + uncleared == total)
    }

    // MARK: - balance(transactions:transfers:accountID:)

    @Test("balance filters transactions by accountID")
    func balanceFiltersByAccount() {
        let other = UUID()
        let foreign = Transaction.post(accountID: other, amount: 500, date: today)
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
        let counterpart = UUID()
        let outgoing = try Transfer.create(
            fromAccountID: accountID,
            toAccountID: counterpart,
            amount: 30,
            date: today
        )
        let incoming = try Transfer.create(
            fromAccountID: counterpart,
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
        let counterpart = UUID()
        var deletedTransfer = try Transfer.create(
            fromAccountID: accountID,
            toAccountID: counterpart,
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
}
