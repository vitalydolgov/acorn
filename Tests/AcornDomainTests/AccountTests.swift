import Foundation
import Testing
@testable import AcornDomain

@Suite("Account")
struct AccountTests {
    // MARK: - Create

    @Test("make trims whitespace from name")
    func makeTrimsWhitespace() {
        let account = Account.make(name: "  Savings  ", notes: "")
        #expect(account?.name == "Savings")
    }

    @Test("make rejects empty name")
    func makeRejectsEmpty() {
        #expect(Account.make(name: "", notes: "") == nil)
    }

    @Test("make rejects whitespace-only name")
    func makeRejectsWhitespaceOnly() {
        #expect(Account.make(name: "   \t\n", notes: "") == nil)
    }

    // MARK: - Update

    @Test("updated rejects empty name")
    func updatedRejectsEmpty() {
        let account = Account.make(name: "A", notes: "")!
        #expect(account.updated(name: "  ", notes: "x") == nil)
    }
}
