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
        let transfers: InMemoryTransferRepository

        // Services
        let recordTransfer: RecordTransfer
        let deleteTransfer: DeleteTransfer

        let seedFrom: Account
        let seedTo: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions, transfers: transfers)
            self.uow = uow

            // Repos
            self.transfers = transfers

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

        func make() async throws -> Transfer {
            try await recordTransfer(
                fromAccountID: seedFrom.id,
                toAccountID: seedTo.id,
                amount: 50,
                date: .today()
            )
        }
    }

    @Test("marks the transfer deleted")
    func marksDeleted() async throws {
        let sut = try await SUT()
        let transfer = try await sut.make()

        try await sut.deleteTransfer(transferID: transfer.id)

        let stored = try #require(try await sut.transfers.fetch(id: transfer.id))
        #expect(stored.isDeleted)
    }

    @Test("fails when already deleted")
    func failsWhenAlreadyDeleted() async throws {
        let sut = try await SUT()
        let transfer = try await sut.make()
        try await sut.deleteTransfer(transferID: transfer.id)

        await #expect(throws: DomainError.deleted) {
            try await sut.deleteTransfer(transferID: transfer.id)
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
