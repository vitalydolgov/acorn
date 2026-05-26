import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ChangeTransferDate")
struct ChangeTransferDateTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transactions: InMemoryTransactionRepository

        // Services
        let recordTransfer: RecordTransfer
        let changeTransferDate: ChangeTransferDate

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
            self.changeTransferDate = ChangeTransferDate(unitOfWork: uow)

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

    @Test("revises date on both legs, preserving their direction and amount")
    func changesBothLegs() async throws {
        let sut = try await SUT()
        let legs = try await sut.recordTransfer(
            fromAccountID: sut.seedFrom.id,
            toAccountID: sut.seedTo.id,
            amount: 10,
            date: Self.today
        )
        let transferID = try #require(legs.from.transferID)
        let next = Self.today.adding(days: 3)

        try await sut.changeTransferDate(transferID: transferID, date: next)

        let from = try #require(try await sut.transactions.fetch(id: legs.from.id))
        let to = try #require(try await sut.transactions.fetch(id: legs.to.id))
        #expect(from.amount == -10)
        #expect(from.date == next)
        #expect(to.amount == 10)
        #expect(to.date == next)
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.changeTransferDate(transferID: UUID(), date: Self.today)
        }
    }
}
