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

    @Test("update rejects a deleted account")
    func updateRejectsDeleted() throws {
        var account = try Account.make(name: "A", notes: "")
        try account.delete()
        #expect(throws: DomainError.deleted) {
            try account.update(name: "B", notes: "")
        }
    }

    // MARK: - close

    @Test("close rejects an already-closed account")
    func closeRejectsAlreadyClosed() throws {
        var account = try Account.make(name: "A", notes: "")
        try account.close()
        #expect(throws: DomainError.invalidState("account is already closed")) {
            try account.close()
        }
    }

    @Test("close rejects a deleted account")
    func closeRejectsDeleted() throws {
        var account = try Account.make(name: "A", notes: "")
        try account.delete()
        #expect(throws: DomainError.deleted) {
            try account.close()
        }
    }

    // MARK: - reopen

    @Test("reopen rejects an account that is not closed")
    func reopenRejectsNotClosed() throws {
        var account = try Account.make(name: "A", notes: "")
        #expect(throws: DomainError.invalidState("account is not closed")) {
            try account.reopen()
        }
    }

    @Test("reopen rejects a deleted account before checking closed state")
    func reopenRejectsDeleted() throws {
        var account = try Account.make(name: "A", notes: "")
        try account.close()
        try account.delete()
        #expect(throws: DomainError.deleted) {
            try account.reopen()
        }
    }

    // MARK: - delete

    @Test("delete is rejected when already deleted")
    func deleteRejectsAlreadyDeleted() throws {
        var account = try Account.make(name: "A", notes: "")
        try account.delete()
        #expect(throws: DomainError.deleted) {
            try account.delete()
        }
    }

    // MARK: - assertPostable

    @Test("assertPostable passes for an open account")
    func assertPostableOpen() throws {
        let account = try Account.make(name: "A", notes: "")
        try account.assertPostable()
    }

    @Test("assertPostable rejects a closed account")
    func assertPostableRejectsClosed() throws {
        var account = try Account.make(name: "A", notes: "")
        try account.close()
        #expect(throws: DomainError.invalidState("account is closed")) {
            try account.assertPostable()
        }
    }

    @Test("assertPostable rejects a deleted account")
    func assertPostableRejectsDeleted() throws {
        var account = try Account.make(name: "A", notes: "")
        try account.delete()
        #expect(throws: DomainError.deleted) {
            try account.assertPostable()
        }
    }
}
