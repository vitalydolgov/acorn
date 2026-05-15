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
}
