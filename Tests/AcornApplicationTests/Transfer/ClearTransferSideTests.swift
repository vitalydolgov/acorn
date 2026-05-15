import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("ClearTransferSide")
struct ClearTransferSideTests {
    private struct SUT {
        let recordTransfer: RecordTransfer
        let clearSide: ClearTransferSide
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
            self.clearSide = ClearTransferSide(transferRepository: transfers)
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

    @Test("flips the chosen side, leaves the other alone")
    func clearOneSide() async throws {
        let sut = try await SUT()
        let transfer = try await sut.make()

        try await sut.clearSide(transferID: transfer.id, side: .from)

        let stored = try #require(try await sut.transfers.get(id: transfer.id))
        #expect(stored.fromStatus == .cleared)
        #expect(stored.toStatus == .uncleared)
    }

    @Test("fails when the side is not uncleared")
    func failsOnCleared() async throws {
        let sut = try await SUT()
        let transfer = try await sut.make()
        try await sut.clearSide(transferID: transfer.id, side: .to)

        await #expect(throws: DomainError.invalidState("transfer side is not uncleared")) {
            try await sut.clearSide(transferID: transfer.id, side: .to)
        }
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.notFound) {
            try await sut.clearSide(transferID: UUID(), side: .from)
        }
    }
}
