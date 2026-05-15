import Foundation
import Testing
@testable import AcornDomain

@Suite("Transfer")
struct TransferTests {
    private let from = UUID()
    private let to = UUID()
    private let today = AcornDate.today()

    // MARK: - Create

    @Test("create stores positive magnitude and from/to identities")
    func createStoresFields() throws {
        let transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 75, date: today)
        #expect(transfer.fromAccountID == from)
        #expect(transfer.toAccountID == to)
        #expect(transfer.amount == 75)
        #expect(transfer.date == today)
        #expect(transfer.fromStatus == .uncleared)
        #expect(transfer.toStatus == .uncleared)
        #expect(transfer.isDeleted == false)
    }

    @Test("create rejects zero amount")
    func createRejectsZero() {
        #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            _ = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 0, date: today)
        }
    }

    @Test("create rejects negative amount")
    func createRejectsNegative() {
        #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            _ = try Transfer.create(fromAccountID: from, toAccountID: to, amount: -1, date: today)
        }
    }

    @Test("create rejects identical from/to")
    func createRejectsSameAccount() {
        let same = UUID()
        #expect(throws: DomainError.invalidArgument("source and destination must differ")) {
            _ = try Transfer.create(fromAccountID: same, toAccountID: same, amount: 10, date: today)
        }
    }

    // MARK: - Update

    @Test("update changes amount and date")
    func updateChangesAmountAndDate() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        let next = today.adding(days: 1)
        try transfer.update(amount: 99, date: next)
        #expect(transfer.amount == 99)
        #expect(transfer.date == next)
    }

    @Test("update rejects non-positive amount")
    func updateRejectsNonPositive() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            try transfer.update(amount: 0, date: today)
        }
        #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            try transfer.update(amount: -5, date: today)
        }
    }

    @Test("update fails on deleted transfer")
    func updateFailsOnDeleted() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.delete()
        #expect(throws: DomainError.deleted) {
            try transfer.update(amount: 20, date: today)
        }
    }

    // MARK: - Status (per side)

    @Test("clear flips a side uncleared to cleared independently")
    func clearOneSide() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.clear(side: .from)
        #expect(transfer.fromStatus == .cleared)
        #expect(transfer.toStatus == .uncleared)
    }

    @Test("clear rejects double-clear")
    func clearRejectsDouble() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.clear(side: .to)
        #expect(throws: DomainError.invalidState("transfer side is not uncleared")) {
            try transfer.clear(side: .to)
        }
    }

    @Test("unclear flips cleared to uncleared")
    func unclearFlipsClearedToUncleared() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.clear(side: .from)
        try transfer.unclear(side: .from)
        #expect(transfer.fromStatus == .uncleared)
    }

    @Test("unclear fails on uncleared side")
    func unclearFailsOnUncleared() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        #expect(throws: DomainError.invalidState("transfer side is not cleared")) {
            try transfer.unclear(side: .from)
        }
    }

    @Test("reconcile promotes cleared side to reconciled")
    func reconcilePromotesCleared() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.clear(side: .to)
        try transfer.reconcile(side: .to)
        #expect(transfer.toStatus == .reconciled)
        #expect(transfer.fromStatus == .uncleared)
    }

    @Test("reconcile rejects uncleared side")
    func reconcileRejectsUncleared() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        #expect(throws: DomainError.invalidState("transfer side is not cleared")) {
            try transfer.reconcile(side: .from)
        }
    }

    @Test("status mutations fail on deleted transfer")
    func statusMutationsFailOnDeleted() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.delete()
        #expect(throws: DomainError.deleted) { try transfer.clear(side: .from) }
        #expect(throws: DomainError.deleted) { try transfer.unclear(side: .from) }
        #expect(throws: DomainError.deleted) { try transfer.reconcile(side: .from) }
    }

    // MARK: - Delete / undelete

    @Test("delete marks transfer deleted")
    func deleteMarks() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.delete()
        #expect(transfer.isDeleted)
    }

    @Test("delete twice fails")
    func deleteTwiceFails() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.delete()
        #expect(throws: DomainError.deleted) { try transfer.delete() }
    }

    @Test("undelete restores the transfer")
    func undeleteRestores() throws {
        var transfer = try Transfer.create(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try transfer.delete()
        transfer.undelete()
        #expect(transfer.isDeleted == false)
        try transfer.update(amount: 20, date: today)
        #expect(transfer.amount == 20)
    }
}
