import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("DeleteTransfer")
struct DeleteTransferTests {
    private struct SUT {
        let recordTransfer: RecordTransfer
        let deleteTransfer: DeleteTransfer
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
            self.deleteTransfer = DeleteTransfer(transferRepository: transfers)
        }

        func make() async throws -> Transfer {
            try await recordTransfer(
                fromAccountID: from.id,
                toAccountID: to.id,
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

        let stored = try #require(try await sut.transfers.get(id: transfer.id))
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
        await #expect(throws: ApplicationError.notFound) {
            try await sut.deleteTransfer(transferID: UUID())
        }
    }
}
