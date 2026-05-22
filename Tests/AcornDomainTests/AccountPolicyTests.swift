import Foundation
import Testing
@testable import AcornDomain

@Suite("AccountPolicy")
struct AccountPolicyTests {
    private let accountID = UUID()
    private let other = UUID()
    private let today = AcornDate.today()

    @Test("allows deletion of an empty account")
    func emptyAccount() {
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [Transaction]()
        ))
    }

    @Test("allows deletion when balance is zero")
    func zeroBalance() throws {
        let plus = Transaction.add(accountID: accountID, amount: 50, date: today)
        let zeroing = try Transaction.adjust(accountID: accountID, amount: -50, date: today)
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [plus, zeroing]
        ))
    }

    @Test("blocks deletion when balance is non-zero")
    func nonZeroBalance() {
        let tx = Transaction.add(accountID: accountID, amount: 10, date: today)
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [tx]
        ) == false)
    }

    @Test("blocks deletion when a live transfer leg references the account")
    func liveTransferBlocks() throws {
        let legs = try Transaction.transfer(
            fromAccountID: accountID,
            toAccountID: other,
            amount: 5,
            date: today
        )
        // Balance is zero, but the live transfer leg still blocks deletion.
        let zeroing = try Transaction.adjust(accountID: accountID, amount: 5, date: today)
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [legs.from, zeroing]
        ) == false)
    }

    @Test("ignores soft-deleted transfer legs and transactions")
    func ignoresSoftDeleted() throws {
        var legs = try Transaction.transfer(
            fromAccountID: accountID,
            toAccountID: other,
            amount: 5,
            date: today
        )
        try legs.from.delete()
        var tx = Transaction.add(accountID: accountID, amount: 10, date: today)
        try tx.delete()
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [legs.from, tx]
        ))
    }

    @Test("ignores transfer legs that do not reference the account")
    func unrelatedTransferIgnored() throws {
        let third = UUID()
        let legs = try Transaction.transfer(
            fromAccountID: other,
            toAccountID: third,
            amount: 5,
            date: today
        )
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [legs.from, legs.to]
        ))
    }
}
