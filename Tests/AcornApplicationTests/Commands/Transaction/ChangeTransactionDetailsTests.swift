import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("ChangeTransactionDetails")
struct ChangeTransactionDetailsTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Commands
        let commands: TransactionCommands

        let seedAccount: Account
        let seedCounterpart: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transactions = transactions

            // Commands
            self.commands = TransactionCommands(unitOfWork: uow)

            var account = try Account.make(name: "Checking", notes: "")
            try await accounts.save(account)
            account = try await accounts.fetch(id: account.id)!
            self.seedAccount = account

            var counterpart = try Account.make(name: "Savings", notes: "")
            try await accounts.save(counterpart)
            counterpart = try await accounts.fetch(id: counterpart.id)!
            self.seedCounterpart = counterpart
        }

        func details(
            amount: Decimal,
            cleared: Bool = false,
            counterpartAccountID: UUID? = nil
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

    @Test("edits a regular transaction in place when no counterpart")
    func editsInPlace() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: SUT.today)

        try await sut.commands.changeDetails(transactionID: tx.id, details: sut.details(amount: 25))

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.amount == 25)
        #expect(stored.isDeleted == false)
        #expect(stored.kind == .regular)
        let active = try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id)
        #expect(active.count == 1)
    }

    @Test("toggles cleared state in place")
    func togglesCleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: SUT.today)

        try await sut.commands.changeDetails(transactionID: tx.id, details: sut.details(amount: 10, cleared: true))

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.status == .cleared)
    }

    @Test("converts a regular transaction into a transfer when a counterpart is given")
    func convertsToTransfer() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -100, date: SUT.today)

        try await sut.commands.changeDetails(
            transactionID: tx.id,
            details: sut.details(amount: -100, counterpartAccountID: sut.seedCounterpart.id)
        )

        // Original transaction is soft-deleted.
        let original = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(original.isDeleted)

        // Two mirrored legs replace it.
        let contextLegs = try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id)
        let counterpartLegs = try await sut.transactions.fetchActive(forAccount: sut.seedCounterpart.id)
        #expect(contextLegs.count == 1)
        #expect(counterpartLegs.count == 1)

        let outflow = try #require(contextLegs.first)
        let inflow = try #require(counterpartLegs.first)
        #expect(outflow.amount == -100)
        #expect(inflow.amount == 100)
        #expect(outflow.isTransferLeg)
        #expect(inflow.isTransferLeg)
        #expect(outflow.transferID == inflow.transferID)
        #expect(outflow.counterpartAccountID == sut.seedCounterpart.id)
        #expect(inflow.counterpartAccountID == sut.seedAccount.id)
    }

    @Test("clears the context leg when converting a cleared transaction to a transfer")
    func convertsClearedToTransfer() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -100, date: SUT.today)

        try await sut.commands.changeDetails(
            transactionID: tx.id,
            details: sut.details(amount: -100, cleared: true, counterpartAccountID: sut.seedCounterpart.id)
        )

        let outflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id).first)
        let inflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedCounterpart.id).first)
        #expect(outflow.status == .cleared)
        #expect(inflow.status == .uncleared)
    }

    @Test("rejects editing a transfer leg directly")
    func rejectsTransferLeg() async throws {
        let sut = try await SUT()
        let legs = try Transaction.transfer(
            fromAccountID: sut.seedAccount.id,
            toAccountID: sut.seedCounterpart.id,
            amount: 10,
            date: SUT.today
        )
        try await sut.transactions.save(legs.from)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDetails(transactionID: legs.from.id, details: sut.details(amount: 5))
        }
    }

    @Test("fails for unknown transaction")
    func failsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDetails(transactionID: UUID(), details: sut.details(amount: 5))
        }
    }

    @Test("rolls back the conversion when the counterpart account is unknown")
    func rollsBackOnUnknownCounterpart() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -100, date: SUT.today)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDetails(
                transactionID: tx.id,
                details: sut.details(amount: -100, counterpartAccountID: UUID())
            )
        }

        // The original transaction must survive the failed conversion.
        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.isDeleted == false)
        #expect(stored.amount == -100)
        #expect(stored.kind == .regular)
    }
}
