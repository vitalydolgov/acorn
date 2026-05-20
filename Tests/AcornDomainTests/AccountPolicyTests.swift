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
            transactions: [Transaction](),
            transfers: [Transfer]()
        ))
    }

    @Test("allows deletion when balance is zero")
    func zeroBalance() throws {
        let plus = Transaction.add(accountID: accountID, amount: 50, date: today)
        let zeroing = try Transaction.adjust(accountID: accountID, amount: -50, date: today)
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [plus, zeroing],
            transfers: [Transfer]()
        ))
    }

    @Test("blocks deletion when balance is non-zero")
    func nonZeroBalance() {
        let tx = Transaction.add(accountID: accountID, amount: 10, date: today)
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [tx],
            transfers: [Transfer]()
        ) == false)
    }

    @Test("blocks deletion when a live transfer references the account")
    func liveTransferBlocks() throws {
        let transfer = try Transfer.create(
            fromAccountID: accountID,
            toAccountID: other,
            amount: 5,
            date: today
        )
        let zeroing = try Transaction.adjust(accountID: accountID, amount: 5, date: today)
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [zeroing],
            transfers: [transfer]
        ) == false)
    }

    @Test("ignores soft-deleted transfers and transactions")
    func ignoresSoftDeleted() throws {
        var transfer = try Transfer.create(
            fromAccountID: accountID,
            toAccountID: other,
            amount: 5,
            date: today
        )
        try transfer.delete()
        var tx = Transaction.add(accountID: accountID, amount: 10, date: today)
        try tx.delete()
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [tx],
            transfers: [transfer]
        ))
    }

    @Test("ignores transfers that do not reference the account")
    func unrelatedTransferIgnored() throws {
        let third = UUID()
        let unrelated = try Transfer.create(
            fromAccountID: other,
            toAccountID: third,
            amount: 5,
            date: today
        )
        #expect(AccountPolicy.canDelete(
            accountID: accountID,
            transactions: [Transaction](),
            transfers: [unrelated]
        ))
    }
}
