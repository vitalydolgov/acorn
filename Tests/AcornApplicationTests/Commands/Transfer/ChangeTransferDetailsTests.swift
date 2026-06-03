import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ChangeTransferDetails")
struct ChangeTransferDetailsTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Commands
        let commands: TransferCommands

        let seedFrom: Account
        let seedTo: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Commands
            self.commands = TransferCommands(unitOfWork: uow)

            var from = try Account.make(name: "Checking", notes: "")
            var to = try Account.make(name: "Savings", notes: "")
            try await accounts.save(from)
            from = try await accounts.fetch(id: from.id)!
            try await accounts.save(to)
            to = try await accounts.fetch(id: to.id)!
            self.seedFrom = from
            self.seedTo = to
        }

        func make(amount: Decimal = 50) async throws -> (from: Transaction, to: Transaction) {
            try await commands.record(
                fromAccountID: seedFrom.id,
                toAccountID: seedTo.id,
                amount: amount,
                date: Self.today
            )
        }

        func details(
            amount: Decimal,
            cleared: Bool = false,
            counterpartAccountID: UUID?
        ) -> TransactionDetails {
            TransactionDetails(
                amount: amount,
                date: Self.today,
                cleared: cleared,
                counterpartAccountID: counterpartAccountID
            )
        }

        static let today = AcornDate.today()
    }

    @Test("replaces both legs with revised amounts")
    func revisesAmount() async throws {
        let sut = try await SUT()
        let legs = try await sut.make(amount: 50)
        let transferID = try #require(legs.from.transferID)

        try await sut.commands.changeDetails(
            transferID: transferID,
            accountID: sut.seedFrom.id,
            details: sut.details(amount: -75, counterpartAccountID: sut.seedTo.id)
        )

        // Old legs are soft-deleted.
        #expect(try #require(try await sut.transactions.fetch(id: legs.from.id)).isDeleted)
        #expect(try #require(try await sut.transactions.fetch(id: legs.to.id)).isDeleted)

        // New mirrored legs carry the revised magnitude.
        let outflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedFrom.id).first)
        let inflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedTo.id).first)
        #expect(outflow.amount == -75)
        #expect(inflow.amount == 75)
        #expect(outflow.isTransferLeg)
        #expect(inflow.isTransferLeg)
        #expect(outflow.transferID == inflow.transferID)
        #expect(outflow.transferID != transferID)
    }

    @Test("replaces the transfer with a plain transaction when no counterpart is given")
    func replacesWithPlainTransaction() async throws {
        let sut = try await SUT()
        let legs = try await sut.make(amount: 50)
        let transferID = try #require(legs.from.transferID)

        try await sut.commands.changeDetails(
            transferID: transferID,
            accountID: sut.seedFrom.id,
            details: sut.details(amount: -50, counterpartAccountID: nil)
        )

        let fromActive = try await sut.transactions.fetchActive(forAccount: sut.seedFrom.id)
        let toActive = try await sut.transactions.fetchActive(forAccount: sut.seedTo.id)
        #expect(fromActive.count == 1)
        #expect(toActive.isEmpty)
        let tx = try #require(fromActive.first)
        #expect(tx.amount == -50)
        #expect(tx.kind == .regular)
        #expect(tx.isTransferLeg == false)
    }

    @Test("clears only the context leg")
    func clearsContextLeg() async throws {
        let sut = try await SUT()
        let legs = try await sut.make(amount: 50)
        let transferID = try #require(legs.from.transferID)

        try await sut.commands.changeDetails(
            transferID: transferID,
            accountID: sut.seedFrom.id,
            details: sut.details(amount: -50, cleared: true, counterpartAccountID: sut.seedTo.id)
        )

        let outflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedFrom.id).first)
        let inflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedTo.id).first)
        #expect(outflow.status == .cleared)
        #expect(inflow.status == .uncleared)
    }

    @Test("fails for unknown transfer")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDetails(
                transferID: UUID(),
                accountID: sut.seedFrom.id,
                details: sut.details(amount: -10, counterpartAccountID: sut.seedTo.id)
            )
        }
    }

    @Test("rolls back the legs when the counterpart account is unknown")
    func rollsBackOnUnknownCounterpart() async throws {
        let sut = try await SUT()
        let legs = try await sut.make(amount: 50)
        let transferID = try #require(legs.from.transferID)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDetails(
                transferID: transferID,
                accountID: sut.seedFrom.id,
                details: sut.details(amount: -50, counterpartAccountID: UUID())
            )
        }

        // The original legs must survive the failed edit.
        #expect(try #require(try await sut.transactions.fetch(id: legs.from.id)).isDeleted == false)
        #expect(try #require(try await sut.transactions.fetch(id: legs.to.id)).isDeleted == false)
    }
}
