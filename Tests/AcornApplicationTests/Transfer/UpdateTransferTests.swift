import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("UpdateTransfer")
struct UpdateTransferTests {
    private struct SUT {
        let recordTransfer: RecordTransfer
        let updateTransfer: UpdateTransfer
        let transfers: InMemoryTransferRepository
        let from: Account
        let to: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transfers = InMemoryTransferRepository()
            let from = try Account.make(name: "Checking", notes: "")
            let to = try Account.make(name: "Savings", notes: "")
            try await accounts.save(from)
            try await accounts.save(to)
            self.transfers = transfers
            self.from = from
            self.to = to
            self.recordTransfer = RecordTransfer(
                accountRepository: accounts,
                transferRepository: transfers
            )
            self.updateTransfer = UpdateTransfer(transferRepository: transfers)
        }
    }

    private static let today = AcornDate.today()

    @Test("changes amount and date")
    func changesAmountAndDate() async throws {
        let sut = try await SUT()
        let transfer = try await sut.recordTransfer(
            fromAccountID: sut.from.id,
            toAccountID: sut.to.id,
            amount: 10,
            date: Self.today
        )
        let next = Self.today.adding(days: 3)

        try await sut.updateTransfer(transferID: transfer.id, amount: 25, date: next)

        let stored = try await sut.transfers.get(id: transfer.id)
        #expect(stored?.amount == 25)
        #expect(stored?.date == next)
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.updateTransfer(transferID: UUID(), amount: 5, date: Self.today)
        }
    }
}
