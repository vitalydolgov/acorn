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
}
