import Foundation
import Testing
@testable import AcornDomain

@Suite("Transaction")
struct TransactionTests {
    private let accountID = UUID()
    private let today = AcornDate.today()

    @Test("adjust returns nil for zero amount")
    func adjustRejectsZero() {
        #expect(Transaction.adjust(accountID: accountID, amount: 0, date: today) == nil)
    }

    @Test("starting returns nil for zero amount")
    func startingRejectsZero() {
        #expect(Transaction.starting(accountID: accountID, amount: 0, date: today) == nil)
    }
}
