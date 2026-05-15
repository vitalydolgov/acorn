import Foundation
import Testing
@testable import AcornApplication
import AcornDomain

@Suite("UnclearTransferSide")
struct UnclearTransferSideTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transfers: InMemoryTransferRepository

        // Services
        let recordTransfer: RecordTransfer
        let clearSide: ClearTransferSide
        let unclearSide: UnclearTransferSide

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
            self.clearSide = ClearTransferSide(unitOfWork: uow)
            self.unclearSide = UnclearTransferSide(unitOfWork: uow)

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

    @Test("restores cleared side to uncleared")
    func restoresClearedSide() async throws {
        let sut = try await SUT()
        let transfer = try await sut.make()
        try await sut.clearSide(transferID: transfer.id, side: .from)

        try await sut.unclearSide(transferID: transfer.id, side: .from)

        let stored = try #require(try await sut.transfers.get(id: transfer.id))
        #expect(stored.fromStatus == .uncleared)
    }

    @Test("fails when side is uncleared")
    func failsOnUncleared() async throws {
        let sut = try await SUT()
        let transfer = try await sut.make()

        await #expect(throws: DomainError.invalidState("transfer side is not cleared")) {
            try await sut.unclearSide(transferID: transfer.id, side: .from)
        }
    }
}
