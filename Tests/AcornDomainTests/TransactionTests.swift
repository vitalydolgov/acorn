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
