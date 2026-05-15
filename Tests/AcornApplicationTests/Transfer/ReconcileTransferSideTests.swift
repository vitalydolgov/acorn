import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("ReconcileTransferSide")
struct ReconcileTransferSideTests {
    private struct SUT {
        // Repos
        let transfers: InMemoryTransferRepository

        // Services
        let recordTransfer: RecordTransfer
        let clearSide: ClearTransferSide
        let reconcileSide: ReconcileTransferSide

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
            self.reconcileSide = ReconcileTransferSide(transferRepository: transfers)

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

    @Test("promotes cleared side")
    func promotesClearedSide() async throws {
        let sut = try await SUT()
        let transfer = try await sut.make()
        try await sut.clearSide(transferID: transfer.id, side: .to)

        try await sut.reconcileSide(transferID: transfer.id, side: .to)

        let stored = try #require(try await sut.transfers.get(id: transfer.id))
        #expect(stored.toStatus == .reconciled)
    }

    @Test("fails for uncleared side")
    func failsForUncleared() async throws {
        let sut = try await SUT()
        let transfer = try await sut.make()

        await #expect(throws: DomainError.invalidState("transfer side is not cleared")) {
            try await sut.reconcileSide(transferID: transfer.id, side: .from)
        }
    }
}
