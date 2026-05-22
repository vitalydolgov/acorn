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
        let transactions: InMemoryTransactionRepository

        // Services
        let recordTransfer: RecordTransfer
        let updateTransfer: UpdateTransfer

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

    @Test("revises both legs, preserving their direction")
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

        try await sut.updateTransfer(transferID: transferID, amount: 25, date: next)

        let from = try #require(try await sut.transactions.fetch(id: legs.from.id))
        let to = try #require(try await sut.transactions.fetch(id: legs.to.id))
        #expect(from.amount == -25)
        #expect(from.date == next)
        #expect(to.amount == 25)
        #expect(to.date == next)
    }

    @Test("fails for non-positive amount")
    func failsForNonPositive() async throws {
        let sut = try await SUT()
        let legs = try await sut.recordTransfer(
            fromAccountID: sut.seedFrom.id,
            toAccountID: sut.seedTo.id,
            amount: 10,
            date: Self.today
        )
        let transferID = try #require(legs.from.transferID)

        await #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            try await sut.updateTransfer(transferID: transferID, amount: 0, date: Self.today)
        }
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.updateTransfer(transferID: UUID(), amount: 5, date: Self.today)
        }
    }
}
