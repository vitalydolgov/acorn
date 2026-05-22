import Foundation
import Testing
@testable import AcornDomain

@Suite("Transfer legs")
struct TransferTests {
    private let from = UUID()
    private let to = UUID()
    private let today = AcornDate.today()

    // MARK: - Create

    @Test("builds two mirrored legs linked by a shared transfer id")
    func createBuildsMirroredLegs() throws {
        let legs = try Transaction.transfer(fromAccountID: from, toAccountID: to, amount: 75, date: today)

        #expect(legs.from.accountID == from)
        #expect(legs.from.amount == -75)
        #expect(legs.from.counterpartAccountID == to)
        #expect(legs.from.status == .uncleared)
        #expect(legs.from.isTransferLeg)
        #expect(legs.from.isDeleted == false)

        #expect(legs.to.accountID == to)
        #expect(legs.to.amount == 75)
        #expect(legs.to.counterpartAccountID == from)
        #expect(legs.to.status == .uncleared)
        #expect(legs.to.isTransferLeg)

        #expect(legs.from.date == today)
        #expect(legs.to.date == today)
        #expect(legs.from.transferID == legs.to.transferID)
        #expect(legs.from.id != legs.to.id)
    }

    @Test("non-transfer transactions expose no transfer linkage")
    func regularTransactionHasNoLinkage() {
        let tx = Transaction.add(accountID: from, amount: 10, date: today)
        #expect(tx.isTransferLeg == false)
        #expect(tx.transferID == nil)
        #expect(tx.counterpartAccountID == nil)
    }

    @Test("create rejects zero amount")
    func createRejectsZero() {
        #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            _ = try Transaction.transfer(fromAccountID: from, toAccountID: to, amount: 0, date: today)
        }
    }

    @Test("create rejects negative amount")
    func createRejectsNegative() {
        #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            _ = try Transaction.transfer(fromAccountID: from, toAccountID: to, amount: -1, date: today)
        }
    }

    @Test("create rejects identical from/to")
    func createRejectsSameAccount() {
        let same = UUID()
        #expect(throws: DomainError.invalidArgument("source and destination must differ")) {
            _ = try Transaction.transfer(fromAccountID: same, toAccountID: same, amount: 10, date: today)
        }
    }

    // MARK: - Revise

    @Test("revise keeps each leg's direction and changes the date")
    func reviseKeepsDirection() throws {
        var legs = try Transaction.transfer(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        let next = today.adding(days: 1)

        try legs.from.reviseTransferLeg(amount: 99, date: next)
        try legs.to.reviseTransferLeg(amount: 99, date: next)

        #expect(legs.from.amount == -99)
        #expect(legs.to.amount == 99)
        #expect(legs.from.date == next)
        #expect(legs.to.date == next)
    }

    @Test("revise rejects non-positive amount")
    func reviseRejectsNonPositive() throws {
        var legs = try Transaction.transfer(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            try legs.from.reviseTransferLeg(amount: 0, date: today)
        }
        #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            try legs.to.reviseTransferLeg(amount: -5, date: today)
        }
    }

    @Test("revise fails on a deleted leg")
    func reviseFailsOnDeleted() throws {
        var legs = try Transaction.transfer(fromAccountID: from, toAccountID: to, amount: 10, date: today)
        try legs.from.delete()
        #expect(throws: DomainError.deleted) {
            try legs.from.reviseTransferLeg(amount: 20, date: today)
        }
    }

    // MARK: - Per-leg status

    @Test("legs clear, unclear, and reconcile independently")
    func legsStatusIndependent() throws {
        var legs = try Transaction.transfer(fromAccountID: from, toAccountID: to, amount: 10, date: today)

        try legs.from.clear()
        #expect(legs.from.status == .cleared)
        #expect(legs.to.status == .uncleared)

        try legs.from.reconcile()
        #expect(legs.from.status == .reconciled)

        try legs.to.clear()
        try legs.to.unclear()
        #expect(legs.to.status == .uncleared)
    }
}
