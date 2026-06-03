import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("TransferCommands")
struct TransferCommandsTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Commands
        let commands: TransferCommands
        let transactionCommands: TransactionCommands

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
            self.transactionCommands = TransactionCommands(unitOfWork: uow)

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
                date: .today()
            )
        }

        func details(
            amount: Decimal,
            cleared: Bool = false,
            counterpartAccountID: UUID?
        ) -> TransactionDetails {
            TransactionDetails(
                amount: amount,
                date: TransferCommandsTests.today,
                cleared: cleared,
                counterpartAccountID: counterpartAccountID
            )
        }
    }

    private static let today = AcornDate.today()

    // MARK: - changeDetails

    @Test("replaces both legs with revised amounts")
    func changeDetailsRevisesAmount() async throws {
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
    func changeDetailsReplacesWithPlainTransaction() async throws {
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
    func changeDetailsClearsContextLeg() async throws {
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
    func changeDetailsFailsForUnknown() async throws {
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
    func changeDetailsRollsBackOnUnknownCounterpart() async throws {
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

    // MARK: - delete

    @Test("marks both legs deleted")
    func deleteMarksDeleted() async throws {
        let sut = try await SUT()
        let legs = try await sut.make()
        let transferID = try #require(legs.from.transferID)

        try await sut.commands.delete(transferID: transferID)

        let from = try #require(try await sut.transactions.fetch(id: legs.from.id))
        let to = try #require(try await sut.transactions.fetch(id: legs.to.id))
        #expect(from.isDeleted)
        #expect(to.isDeleted)
    }

    @Test("fails when already deleted")
    func deleteFailsWhenAlreadyDeleted() async throws {
        let sut = try await SUT()
        let legs = try await sut.make()
        let transferID = try #require(legs.from.transferID)
        try await sut.commands.delete(transferID: transferID)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.delete(transferID: transferID)
        }
    }

    @Test("fails for unknown transfer")
    func deleteFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.delete(transferID: UUID())
        }
    }

    // MARK: - record

    @Test("stores two mirrored legs that balance the two accounts")
    func recordStoresTwoLegs() async throws {
        let sut = try await SUT()

        let legs = try await sut.commands.record(
            fromAccountID: sut.seedFrom.id,
            toAccountID: sut.seedTo.id,
            amount: 100,
            date: Self.today
        )

        // Outflow leg on the source account.
        #expect(legs.from.accountID == sut.seedFrom.id)
        #expect(legs.from.amount == -100)
        #expect(legs.from.counterpartAccountID == sut.seedTo.id)
        #expect(legs.from.status == .uncleared)
        #expect(legs.from.isTransferLeg)

        // Inflow leg on the destination account.
        #expect(legs.to.accountID == sut.seedTo.id)
        #expect(legs.to.amount == 100)
        #expect(legs.to.counterpartAccountID == sut.seedFrom.id)
        #expect(legs.to.status == .uncleared)
        #expect(legs.to.isTransferLeg)

        // Both legs share one transfer id.
        #expect(legs.from.transferID == legs.to.transferID)

        // Each account's register fetches the leg as a plain transaction.
        let fromTxs = try await sut.transactions.fetchActive(forAccount: sut.seedFrom.id)
        let toTxs = try await sut.transactions.fetchActive(forAccount: sut.seedTo.id)
        #expect(fromTxs.count == 1)
        #expect(toTxs.count == 1)

        #expect(
            BalanceCalculator.balance(transactions: fromTxs, accountID: sut.seedFrom.id) == -100
        )
        #expect(
            BalanceCalculator.balance(transactions: toTxs, accountID: sut.seedTo.id) == 100
        )
    }

    @Test("fails when source account is unknown")
    func recordFailsForUnknownFrom() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.commands.record(
                fromAccountID: UUID(),
                toAccountID: sut.seedTo.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails when destination account is unknown")
    func recordFailsForUnknownTo() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.commands.record(
                fromAccountID: sut.seedFrom.id,
                toAccountID: UUID(),
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails on a closed account")
    func recordFailsOnClosed() async throws {
        let sut = try await SUT()
        var closed = sut.seedFrom
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.commands.record(
                fromAccountID: sut.seedFrom.id,
                toAccountID: sut.seedTo.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails on a deleted account")
    func recordFailsOnDeleted() async throws {
        let sut = try await SUT()
        var deleted = sut.seedTo
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            _ = try await sut.commands.record(
                fromAccountID: sut.seedFrom.id,
                toAccountID: sut.seedTo.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails when accounts are the same")
    func recordFailsForSameAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("source and destination must differ")) {
            _ = try await sut.commands.record(
                fromAccountID: sut.seedFrom.id,
                toAccountID: sut.seedFrom.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails for non-positive amount")
    func recordFailsForNonPositive() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            _ = try await sut.commands.record(
                fromAccountID: sut.seedFrom.id,
                toAccountID: sut.seedTo.id,
                amount: 0,
                date: Self.today
            )
        }
    }

    // MARK: - leg status

    /// Transfer legs are plain transactions, so their cleared/uncleared/reconciled
    /// status is driven through the regular transaction use cases — one leg at a
    /// time, independently of its counterpart.
    @Test("clearing one leg leaves the counterpart untouched")
    func legStatusClearsOneLegIndependently() async throws {
        let sut = try await SUT()
        let legs = try await sut.commands.record(
            fromAccountID: sut.seedFrom.id,
            toAccountID: sut.seedTo.id,
            amount: 40,
            date: .today()
        )

        try await sut.transactionCommands.clear(transactionID: legs.from.id)

        let from = try #require(try await sut.transactions.fetch(id: legs.from.id))
        let to = try #require(try await sut.transactions.fetch(id: legs.to.id))
        #expect(from.status == .cleared)
        #expect(to.status == .uncleared)
    }
}
