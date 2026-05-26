import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("DeleteTransfer")
struct DeleteTransferTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transactions: InMemoryTransactionRepository

        // Services
        let recordTransfer: RecordTransfer
        let deleteTransfer: DeleteTransfer

        let seedFrom: Account
        let seedTo: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.transactions = transactions

            // Services
            self.recordTransfer = RecordTransfer(unitOfWork: uow)
            self.deleteTransfer = DeleteTransfer(unitOfWork: uow)

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
            try await recordTransfer(
                fromAccountID: seedFrom.id,
                toAccountID: seedTo.id,
                amount: 50,
                date: .today()
            )
        }
    }

    @Test("marks both legs deleted")
    func marksDeleted() async throws {
        let sut = try await SUT()
        let legs = try await sut.make()
        let transferID = try #require(legs.from.transferID)

        try await sut.deleteTransfer(transferID: transferID)

        let from = try #require(try await sut.transactions.fetch(id: legs.from.id))
        let to = try #require(try await sut.transactions.fetch(id: legs.to.id))
        #expect(from.isDeleted)
        #expect(to.isDeleted)
    }

    @Test("fails when already deleted")
    func failsWhenAlreadyDeleted() async throws {
        let sut = try await SUT()
        let legs = try await sut.make()
        let transferID = try #require(legs.from.transferID)
        try await sut.deleteTransfer(transferID: transferID)

        await #expect(throws: DomainError.deleted) {
            try await sut.deleteTransfer(transferID: transferID)
        }
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.deleteTransfer(transferID: UUID())
        }
    }
}
