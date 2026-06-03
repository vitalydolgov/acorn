import Foundation
import Testing
@testable import AcornDomain

@Suite("Transaction")
struct TransactionTests {
    private let accountID = UUID()
    private let today = AcornDate.today()

    private func makeUncleared() -> Transaction {
        Transaction.add(accountID: accountID, amount: 10, date: today)
    }

    private func makeCleared() -> Transaction {
        Transaction.add(accountID: accountID, amount: 10, date: today, cleared: true)
    }

    private func makeReconciled() throws -> Transaction {
        var tx = makeCleared()
        try tx.reconcile()
        return tx
    }

    // MARK: - adjust

    @Test("adjust throws for zero amount")
    func adjustRejectsZero() {
        #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try Transaction.adjust(accountID: accountID, amount: 0, date: today)
        }
    }

    // MARK: - clear

    @Test("clear rejects an already-cleared transaction")
    func clearRejectsCleared() {
        var tx = makeCleared()
        #expect(throws: DomainError.invalidState("transaction is not uncleared")) {
            try tx.clear()
        }
    }

    @Test("clear rejects a reconciled transaction")
    func clearRejectsReconciled() throws {
        var tx = try makeReconciled()
        #expect(throws: DomainError.invalidState("transaction is not uncleared")) {
            try tx.clear()
        }
    }

    @Test("clear rejects a deleted transaction")
    func clearRejectsDeleted() throws {
        var tx = makeUncleared()
        try tx.delete()
        #expect(throws: DomainError.deleted) {
            try tx.clear()
        }
    }

    // MARK: - unclear

    @Test("unclear rejects an uncleared transaction")
    func unclearRejectsUncleared() {
        var tx = makeUncleared()
        #expect(throws: DomainError.invalidState("transaction is not cleared")) {
            try tx.unclear()
        }
    }

    @Test("unclear rejects a reconciled transaction")
    func unclearRejectsReconciled() throws {
        var tx = try makeReconciled()
        #expect(throws: DomainError.invalidState("transaction is not cleared")) {
            try tx.unclear()
        }
    }

    @Test("unclear rejects a deleted transaction before checking status")
    func unclearRejectsDeleted() throws {
        var tx = makeCleared()
        try tx.delete()
        #expect(throws: DomainError.deleted) {
            try tx.unclear()
        }
    }

    // MARK: - reconcile

    @Test("reconcile rejects an uncleared transaction")
    func reconcileRejectsUncleared() {
        var tx = makeUncleared()
        #expect(throws: DomainError.invalidState("transaction is not cleared")) {
            try tx.reconcile()
        }
    }

    @Test("reconcile rejects an already-reconciled transaction")
    func reconcileRejectsReconciled() throws {
        var tx = try makeReconciled()
        #expect(throws: DomainError.invalidState("transaction is not cleared")) {
            try tx.reconcile()
        }
    }

    @Test("reconcile rejects a deleted transaction before checking status")
    func reconcileRejectsDeleted() throws {
        var tx = makeCleared()
        try tx.delete()
        #expect(throws: DomainError.deleted) {
            try tx.reconcile()
        }
    }

    // MARK: - setCleared

    @Test("setCleared(true) clears an uncleared transaction")
    func setClearedClearsUncleared() throws {
        var tx = makeUncleared()
        try tx.setCleared(true)
        #expect(tx.status == .cleared)
    }

    @Test("setCleared(false) unclears a cleared transaction")
    func setClearedUnclearsCleared() throws {
        var tx = makeCleared()
        try tx.setCleared(false)
        #expect(tx.status == .uncleared)
    }

    @Test("setCleared is a no-op when already in the target state")
    func setClearedNoOpInTargetState() throws {
        var cleared = makeCleared()
        try cleared.setCleared(true)
        #expect(cleared.status == .cleared)

        var uncleared = makeUncleared()
        try uncleared.setCleared(false)
        #expect(uncleared.status == .uncleared)
    }

    @Test("setCleared leaves a reconciled transaction untouched in either direction")
    func setClearedNoOpOnReconciled() throws {
        var toCleared = try makeReconciled()
        try toCleared.setCleared(true)
        #expect(toCleared.status == .reconciled)

        var toUncleared = try makeReconciled()
        try toUncleared.setCleared(false)
        #expect(toUncleared.status == .reconciled)
    }

    @Test("setCleared propagates the deleted guard from the underlying transition")
    func setClearedThrowsOnDeletedTransition() throws {
        var tx = makeUncleared()
        try tx.delete()
        #expect(throws: DomainError.deleted) {
            try tx.setCleared(true)
        }
    }

    // MARK: - update

    @Test("update rejects a deleted transaction")
    func updateRejectsDeleted() throws {
        var tx = makeUncleared()
        try tx.delete()
        #expect(throws: DomainError.deleted) {
            try tx.update(amount: 5, date: today)
        }
    }

    @Test("update rejects a split transaction")
    func updateRejectsSplit() throws {
        var tx = try Transaction.split(accountID: accountID, amount: 10, date: today, lineAmounts: [3, 7])
        #expect(throws: DomainError.invalidState("transaction is split")) {
            try tx.update(amount: 5, date: today)
        }
    }

    // MARK: - split

    @Test("a regular transaction is a single line and is not split")
    func regularIsSingleLine() {
        let tx = makeUncleared()
        #expect(tx.lines.count == 1)
        #expect(tx.isSplit == false)
        #expect(tx.amount == 10)
    }

    @Test("split divides the amount across its lines")
    func splitDividesAmount() throws {
        let tx = try Transaction.split(accountID: accountID, amount: -100, date: today, lineAmounts: [-60, -40])
        #expect(tx.isSplit)
        #expect(tx.lines.count == 2)
        #expect(tx.amount == -100)
        #expect(tx.kind == .regular)
        #expect(tx.status == .uncleared)
    }

    @Test("split can be created cleared")
    func splitCanBeCleared() throws {
        let tx = try Transaction.split(accountID: accountID, amount: 3, date: today, cleared: true, lineAmounts: [1, 2])
        #expect(tx.status == .cleared)
    }

    @Test("split rejects fewer than two lines")
    func splitRejectsTooFewLines() {
        #expect(throws: DomainError.invalidArgument("a split needs at least two lines")) {
            _ = try Transaction.split(accountID: accountID, amount: 10, date: today, lineAmounts: [10])
        }
    }

    @Test("split rejects a zero line amount")
    func splitRejectsZeroLine() {
        #expect(throws: DomainError.invalidArgument("split line amounts must be non-zero")) {
            _ = try Transaction.split(accountID: accountID, amount: 10, date: today, lineAmounts: [10, 0])
        }
    }

    @Test("split rejects lines that do not sum to the amount")
    func splitRejectsUnbalancedLines() {
        #expect(throws: DomainError.invalidArgument("split lines must sum to the transaction amount")) {
            _ = try Transaction.split(accountID: accountID, amount: -100, date: today, lineAmounts: [-60, -30])
        }
    }

    // MARK: - reviseSplit

    @Test("reviseSplit replaces the lines and divides the amount")
    func reviseSplitReplacesLines() throws {
        var tx = makeUncleared()
        try tx.reviseSplit(amount: -100, lineAmounts: [-20, -30, -50], date: today)
        #expect(tx.isSplit)
        #expect(tx.lines.count == 3)
        #expect(tx.amount == -100)
    }

    @Test("reviseSplit rejects a deleted transaction")
    func reviseSplitRejectsDeleted() throws {
        var tx = makeUncleared()
        try tx.delete()
        #expect(throws: DomainError.deleted) {
            try tx.reviseSplit(amount: 3, lineAmounts: [1, 2], date: today)
        }
    }

    @Test("reviseSplit rejects fewer than two lines")
    func reviseSplitRejectsTooFewLines() throws {
        var tx = makeUncleared()
        #expect(throws: DomainError.invalidArgument("a split needs at least two lines")) {
            try tx.reviseSplit(amount: 5, lineAmounts: [5], date: today)
        }
    }

    @Test("reviseSplit rejects lines that do not sum to the amount")
    func reviseSplitRejectsUnbalancedLines() throws {
        var tx = makeUncleared()
        #expect(throws: DomainError.invalidArgument("split lines must sum to the transaction amount")) {
            try tx.reviseSplit(amount: 10, lineAmounts: [3, 5], date: today)
        }
    }

    // MARK: - setDate

    @Test("setDate changes the date of a split without touching its lines")
    func setDateKeepsSplitLines() throws {
        var tx = try Transaction.split(accountID: accountID, amount: 10, date: today, lineAmounts: [3, 7])
        let later = today.adding(days: 5)
        try tx.setDate(later)
        #expect(tx.date == later)
        #expect(tx.amount == 10)
        #expect(tx.lines.count == 2)
    }

    // MARK: - delete

    @Test("delete rejects an already-deleted transaction")
    func deleteRejectsAlreadyDeleted() throws {
        var tx = makeUncleared()
        try tx.delete()
        #expect(throws: DomainError.deleted) {
            try tx.delete()
        }
    }
}
