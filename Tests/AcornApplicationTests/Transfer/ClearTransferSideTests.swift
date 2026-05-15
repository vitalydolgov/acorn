import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("ClearTransferSide")
struct ClearTransferSideTests {
    private struct SUT {
        // Repos
        let transfers: InMemoryTransferRepository

        // Services
        let recordTransfer: RecordTransfer
        let clearSide: ClearTransferSide

        let seedFrom: Account
        let seedTo: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transfers = InMemoryTransferRepository()

            // Repos
            self.transfers = transfers

            // Services
            self.recordTransfer = RecordTransfer(
                accountRepository: accounts,
                transferRepository: transfers
            )
            self.clearSide = ClearTransferSide(transferRepository: transfers)

            var from = try Account.make(name: "Checking", notes: "")
            var to = try Account.make(name: "Savings", notes: "")
            try await accounts.save(from)
            from = try await accounts.get(id: from.id)!
            try await accounts.save(to)
            to = try await accounts.get(id: to.id)!
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
