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

    /// Outflow leg on `accountID`.
    private func outgoing(_ amount: Decimal) throws -> Transaction {
        try Transaction.transfer(fromAccountID: accountID, toAccountID: other, amount: amount, date: today).from
    }

    /// Inflow leg on `accountID`.
    private func incoming(_ amount: Decimal) throws -> Transaction {
        try Transaction.transfer(fromAccountID: other, toAccountID: accountID, amount: amount, date: today).to
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
            BalanceCalculator.balance(transactions: txs, accountID: accountID) == 145
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
            BalanceCalculator.balance(transactions: txs, accountID: accountID) == 100
        )
    }

    @Test("balance of empty sequence is zero")
    func balanceOfEmptyIsZero() {
        #expect(
            BalanceCalculator.balance(transactions: [Transaction](), accountID: accountID) == 0
        )
    }

    @Test("balance filters transactions by accountID")
    func balanceFiltersByAccount() {
        let foreign = Transaction.add(accountID: other, amount: 500, date: today)
        let txs = [deposit(100), foreign]
        #expect(
            BalanceCalculator.balance(transactions: txs, accountID: accountID) == 100
        )
    }

    @Test("balance subtracts outgoing transfer legs and adds incoming")
    func balanceAppliesTransferLegs() throws {
        let txs = [deposit(100), try outgoing(30), try incoming(10)]
        #expect(
            BalanceCalculator.balance(transactions: txs, accountID: accountID) == 80
        )
    }

    @Test("balance skips deleted transfer legs")
    func balanceSkipsDeletedTransfers() throws {
        var deletedLeg = try outgoing(30)
        try deletedLeg.delete()
        let txs = [deposit(100), deletedLeg]
        #expect(
            BalanceCalculator.balance(transactions: txs, accountID: accountID) == 100
        )
    }

    @Test("balance ignores transfer legs that do not involve the account")
    func balanceIgnoresUnrelatedTransfers() throws {
        let a = UUID(), b = UUID()
        let unrelated = try Transaction.transfer(fromAccountID: a, toAccountID: b, amount: 50, date: today)
        let txs = [deposit(100), unrelated.from, unrelated.to]
        #expect(
            BalanceCalculator.balance(transactions: txs, accountID: accountID) == 100
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
            BalanceCalculator.clearedBalance(transactions: txs, accountID: accountID) == 75
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
            BalanceCalculator.clearedBalance(transactions: txs, accountID: accountID) == 50
        )
    }

    @Test("clearedBalance counts only transfer legs that are cleared")
    func clearedBalanceAppliesClearedTransferLegs() throws {
        let clearedOut = try cleared(try outgoing(30))
        let unclearedIn = try incoming(10)
        let txs = [try cleared(deposit(100)), clearedOut, unclearedIn]
        #expect(
            BalanceCalculator.clearedBalance(transactions: txs, accountID: accountID) == 70
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
            BalanceCalculator.unclearedBalance(transactions: txs, accountID: accountID) == 60
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
            BalanceCalculator.unclearedBalance(transactions: txs, accountID: accountID) == 100
        )
    }

    @Test("unclearedBalance counts only transfer legs that are uncleared")
    func unclearedBalanceAppliesUnclearedTransferLegs() throws {
        let clearedOut = try cleared(try outgoing(30))
        let unclearedIn = try incoming(10)
        let txs = [deposit(100), clearedOut, unclearedIn]
        #expect(
            BalanceCalculator.unclearedBalance(transactions: txs, accountID: accountID) == 110
        )
    }

    // MARK: - invariant

    @Test("cleared + uncleared equals total balance, including transfer legs")
    func clearedPlusUnclearedEqualsBalance() throws {
        var deletedDeposit = deposit(999)
        try deletedDeposit.delete()
        let txs = [
            deposit(100),
            try cleared(deposit(50)),
            try reconciled(deposit(25)),
            withdraw(30),
            deletedDeposit,
            try cleared(try outgoing(30)),
            try incoming(10),
        ]
        let total = BalanceCalculator.balance(transactions: txs, accountID: accountID)
        let cleared = BalanceCalculator.clearedBalance(transactions: txs, accountID: accountID)
        let uncleared = BalanceCalculator.unclearedBalance(transactions: txs, accountID: accountID)
        #expect(cleared + uncleared == total)
    }
}
