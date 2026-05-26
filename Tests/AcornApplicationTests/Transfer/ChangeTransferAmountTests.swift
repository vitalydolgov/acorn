import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ChangeTransferAmount")
struct ChangeTransferAmountTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let transactions: InMemoryTransactionRepository

        // Services
        let recordTransfer: RecordTransfer
        let changeTransferAmount: ChangeTransferAmount

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
            self.changeTransferAmount = ChangeTransferAmount(unitOfWork: uow)

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

    @Test("revises amount on both legs, preserving their direction and date")
    func changesBothLegs() async throws {
        let sut = try await SUT()
        let legs = try await sut.recordTransfer(
            fromAccountID: sut.seedFrom.id,
            toAccountID: sut.seedTo.id,
            amount: 10,
            date: Self.today
        )
        let transferID = try #require(legs.from.transferID)

        try await sut.changeTransferAmount(transferID: transferID, amount: 25)

        let from = try #require(try await sut.transactions.fetch(id: legs.from.id))
        let to = try #require(try await sut.transactions.fetch(id: legs.to.id))
        #expect(from.amount == -25)
        #expect(from.date == Self.today)
        #expect(to.amount == 25)
        #expect(to.date == Self.today)
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
            try await sut.changeTransferAmount(transferID: transferID, amount: 0)
        }
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.changeTransferAmount(transferID: UUID(), amount: 5)
        }
    }
}
