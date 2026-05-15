import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("OpenAccount")
struct OpenAccountTests {
    private struct SUT {
        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Services
        let openAccount: OpenAccount

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Services
            self.openAccount = OpenAccount(accountRepository: accounts)
        }
    }

    @Test("opens an account with name and notes")
    func opensWithNameAndNotes() async throws {
        let sut = SUT()

        let account = try await sut.openAccount(name: "Checking", notes: "Primary")

        #expect(account.name == "Checking")
        #expect(account.notes == "Primary")
        #expect(account.isClosed == false)

        let stored = try await sut.accounts.get(id: account.id)
        #expect(stored?.name == "Checking")
        #expect(stored?.notes == "Primary")
    }

    @Test("open writes no transactions")
    func openWritesNoTransactions() async throws {
        let sut = SUT()

        let account = try await sut.openAccount(name: "Savings")
        let txs = try await sut.transactions.forAccount(account.id)

        #expect(txs.isEmpty)
    }

    @Test("rejects empty name")
    func rejectsEmptyName() async throws {
        let sut = SUT()

        await #expect(throws: DomainError.invalidArgument("name must not be blank")) {
            _ = try await sut.openAccount(name: "   ")
        }
        #expect(try await sut.accounts.all().isEmpty)
    }
}
