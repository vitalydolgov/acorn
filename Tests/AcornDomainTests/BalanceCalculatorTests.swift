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

    private func cleared(_ tx: Transaction) -> Transaction { tx.cleared() }
    private func reconciled(_ tx: Transaction) -> Transaction { tx.cleared().reconciled() }
    private func deleted(_ tx: Transaction) -> Transaction { tx.deleted() }

    // MARK: - balance

    @Test("balance sums all non-deleted transactions regardless of status")
    func balanceSumsAllNonDeleted() {
        let txs = [
            deposit(100),                  // uncleared
            cleared(deposit(50)),          // cleared
            reconciled(deposit(25)),       // reconciled
            withdraw(30),                  // uncleared, -30
        ]
        #expect(BalanceCalculator.balance(of: txs) == 145)
    }

    @Test("balance skips deleted transactions")
    func balanceSkipsDeleted() {
        let txs = [
            deposit(100),
            deleted(deposit(999)),
        ]
        #expect(BalanceCalculator.balance(of: txs) == 100)
    }

    @Test("balance of empty sequence is zero")
    func balanceOfEmptyIsZero() {
        #expect(BalanceCalculator.balance(of: [Transaction]()) == 0)
    }

    // MARK: - clearedBalance

    @Test("clearedBalance includes cleared and reconciled, excludes uncleared")
    func clearedBalanceIncludesClearedAndReconciled() {
        let txs = [
            deposit(100),                // uncleared, excluded
            cleared(deposit(50)),
            reconciled(deposit(25)),
        ]
        #expect(BalanceCalculator.clearedBalance(of: txs) == 75)
    }

    @Test("clearedBalance skips deleted transactions")
    func clearedBalanceSkipsDeleted() {
        let txs = [
            cleared(deposit(50)),
            deleted(cleared(deposit(999))),
        ]
        #expect(BalanceCalculator.clearedBalance(of: txs) == 50)
    }

    // MARK: - unclearedBalance

    @Test("unclearedBalance only counts uncleared transactions")
    func unclearedBalanceOnlyUncleared() {
        let txs = [
            deposit(100),                // uncleared
            cleared(deposit(50)),        // excluded
            reconciled(deposit(25)),     // excluded
            withdraw(40),                // uncleared, -40
        ]
        #expect(BalanceCalculator.unclearedBalance(of: txs) == 60)
    }

    @Test("unclearedBalance skips deleted transactions")
    func unclearedBalanceSkipsDeleted() {
        let txs = [
            deposit(100),
            deleted(deposit(999)),
        ]
        #expect(BalanceCalculator.unclearedBalance(of: txs) == 100)
    }

    @Test("cleared + uncleared equals total balance")
    func clearedPlusUnclearedEqualsBalance() {
        let txs = [
            deposit(100),
            cleared(deposit(50)),
            reconciled(deposit(25)),
            withdraw(30),
            deleted(deposit(999)),
        ]
        let total = BalanceCalculator.balance(of: txs)
        let cleared = BalanceCalculator.clearedBalance(of: txs)
        let uncleared = BalanceCalculator.unclearedBalance(of: txs)
        #expect(cleared + uncleared == total)
    }
}
