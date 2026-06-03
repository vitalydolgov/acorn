import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ListTransferLegs")
struct ListTransferLegsTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Commands & queries
        let commands: TransferCommands
        let queries: TransactionQueries

        let seedFrom: Account
        let seedTo: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Commands & queries
            self.commands = TransferCommands(unitOfWork: uow)
            self.queries = TransactionQueries(unitOfWork: uow)

            var from = try Account.make(name: "Checking", notes: "")
            var to = try Account.make(name: "Savings", notes: "")
            try await accounts.save(from)
            from = try await accounts.fetch(id: from.id)!
            try await accounts.save(to)
            to = try await accounts.fetch(id: to.id)!
            self.seedFrom = from
            self.seedTo = to
        }

        func make() async throws -> (from: Transaction, to: Transaction) {
            try await commands.record(
                fromAccountID: seedFrom.id,
                toAccountID: seedTo.id,
                amount: 50,
                date: .today()
            )
        }
    }

    @Test("returns both legs of a transfer")
    func returnsBothLegs() async throws {
        let sut = try await SUT()
        let legs = try await sut.make()
        let transferID = try #require(legs.from.transferID)

        let result = try await sut.queries.listTransferLegs(transferID: transferID)
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.isTransferLeg })
        #expect(Set(result.map(\.id)) == [legs.from.id, legs.to.id])
        #expect(result.allSatisfy { $0.transferID == transferID })
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.queries.listTransferLegs(transferID: UUID())
        }
    }
}
