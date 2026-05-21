import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("UpdateTransfer")
struct UpdateTransferTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transfers: InMemoryTransferRepository

        // Services
        let recordTransfer: RecordTransfer
        let updateTransfer: UpdateTransfer

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
            self.updateTransfer = UpdateTransfer(unitOfWork: uow)

            var from = try Account.make(name: "Checking", notes: "")
            var to = try Account.make(name: "Savings", notes: "")
            try await accounts.save(from)
            from = try await accounts.fetch(id: from.id)!
            try await accounts.save(to)
            to = try await accounts.fetch(id: to.id)!
            self.seedFrom = from
            self.seedTo = to
        }
    }

    private static let today = AcornDate.today()

    @Test("changes amount and date")
    func changesAmountAndDate() async throws {
        let sut = try await SUT()
        let transfer = try await sut.recordTransfer(
            fromAccountID: sut.seedFrom.id,
            toAccountID: sut.seedTo.id,
            amount: 10,
            date: Self.today
        )
        let next = Self.today.adding(days: 3)

        try await sut.updateTransfer(transferID: transfer.id, amount: 25, date: next)

        let stored = try await sut.transfers.fetch(id: transfer.id)
        #expect(stored?.amount == 25)
        #expect(stored?.date == next)
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.updateTransfer(transferID: UUID(), amount: 5, date: Self.today)
        }
    }
}
