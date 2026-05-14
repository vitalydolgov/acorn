import Foundation
import Testing
@testable import AcornDomain

@Suite("Account")
struct AccountTests {
    // MARK: - Create

    @Test("make trims whitespace from name")
    func makeTrimsWhitespace() throws {
        let account = try Account.make(name: "  Savings  ", notes: "")
        #expect(account.name == "Savings")
    }

    @Test("make rejects empty name")
    func makeRejectsEmpty() {
        #expect(throws: DomainError.invalidArgument("name must not be blank")) {
            _ = try Account.make(name: "", notes: "")
        }
    }

    @Test("make rejects whitespace-only name")
    func makeRejectsWhitespaceOnly() {
        #expect(throws: DomainError.invalidArgument("name must not be blank")) {
            _ = try Account.make(name: "   \t\n", notes: "")
        }
    }

    // MARK: - Update

    @Test("update rejects empty name")
    func updateRejectsEmpty() throws {
        var account = try Account.make(name: "A", notes: "")
        #expect(throws: DomainError.self) {
            try account.update(name: "  ", notes: "x")
        }
    }
}
