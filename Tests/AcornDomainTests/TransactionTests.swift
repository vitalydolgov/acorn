import Foundation
import Testing
@testable import AcornDomain

@Suite("Transaction")
struct TransactionTests {
    private let accountID = UUID()
    private let today = AcornDate.today()

    @Test("adjust throws for zero amount")
    func adjustRejectsZero() {
        #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try Transaction.adjust(accountID: accountID, amount: 0, date: today)
        }
    }

    @Test("starting throws for zero amount")
    func startingRejectsZero() {
        #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try Transaction.starting(accountID: accountID, amount: 0, date: today)
        }
    }

    @Test("transfer produces a mirrored linked pair")
    func transferLinksPair() throws {
        let from = UUID(), to = UUID()
        let pair = try Transaction.transfer(fromAccountID: from, toAccountID: to, amount: 40, date: today)

        #expect(pair.outflow.accountID == from)
        #expect(pair.outflow.amount == -40)
        #expect(pair.inflow.accountID == to)
        #expect(pair.inflow.amount == 40)
        #expect(pair.outflow.kind == .transfer(counterpartID: pair.inflow.id))
        #expect(pair.inflow.kind == .transfer(counterpartID: pair.outflow.id))
    }

    @Test("transfer normalizes the sign")
    func transferNormalizesSign() throws {
        let pair = try Transaction.transfer(fromAccountID: UUID(), toAccountID: UUID(), amount: -25, date: today)
        #expect(pair.outflow.amount == -25)
        #expect(pair.inflow.amount == 25)
    }

    @Test("transfer throws for zero amount")
    func transferRejectsZero() {
        #expect(throws: DomainError.invalidArgument("amount must be non-zero")) {
            _ = try Transaction.transfer(fromAccountID: UUID(), toAccountID: UUID(), amount: 0, date: today)
        }
    }

    @Test("transfer throws when accounts are the same")
    func transferRejectsSameAccount() {
        let same = UUID()
        #expect(throws: DomainError.invalidArgument("source and destination must differ")) {
            _ = try Transaction.transfer(fromAccountID: same, toAccountID: same, amount: 10, date: today)
        }
    }
}
