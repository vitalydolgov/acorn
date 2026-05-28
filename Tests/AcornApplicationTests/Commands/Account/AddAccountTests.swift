import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("AddAccount")
struct AddAccountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Commands
        let commands: AccountCommands

        init() {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Commands
            self.commands = AccountCommands(unitOfWork: uow, todayProvider: FixedTodayProvider(date: .today()))
        }
    }

    @Test("opens an account with name and notes")
    func opensWithNameAndNotes() async throws {
        let sut = SUT()

        let account = try await sut.commands.add(name: "Checking", notes: "Primary")

        #expect(account.name == "Checking")
        #expect(account.notes == "Primary")
        #expect(account.isClosed == false)

        let stored = try await sut.accounts.fetch(id: account.id)
        #expect(stored?.name == "Checking")
        #expect(stored?.notes == "Primary")
    }

    @Test("open writes no transactions")
    func openWritesNoTransactions() async throws {
        let sut = SUT()

        let account = try await sut.commands.add(name: "Savings")
        let txs = try await sut.transactions.fetchActive(forAccount: account.id)

        #expect(txs.isEmpty)
    }

    @Test("rejects empty name")
    func rejectsEmptyName() async throws {
        let sut = SUT()

        await #expect(throws: DomainError.invalidArgument("name must not be blank")) {
            _ = try await sut.commands.add(name: "   ")
        }
        #expect(try await sut.accounts.fetchActive().isEmpty)
    }
}
