import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("RecordTransactionDetails")
struct RecordTransactionDetailsTests {
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

    @Test("records a regular transaction when no counterpart is given")
    func recordsRegular() async throws {
        let sut = try await SUT()

        try await sut.commands.recordDetails(accountID: sut.seedAccount.id, details: sut.details(amount: 50))

        let active = try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id)
        #expect(active.count == 1)
        let tx = try #require(active.first)
        #expect(tx.amount == 50)
        #expect(tx.kind == .regular)
        #expect(tx.status == .uncleared)
    }

    @Test("records a cleared regular transaction")
    func recordsClearedRegular() async throws {
        let sut = try await SUT()

        try await sut.commands.recordDetails(accountID: sut.seedAccount.id, details: sut.details(amount: 50, cleared: true))

        let tx = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id).first)
        #expect(tx.status == .cleared)
    }

    @Test("records a transfer when a counterpart is given")
    func recordsTransfer() async throws {
        let sut = try await SUT()

        try await sut.commands.recordDetails(
            accountID: sut.seedAccount.id,
            details: sut.details(amount: -100, counterpartAccountID: sut.seedCounterpart.id)
        )

        let outflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id).first)
        let inflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedCounterpart.id).first)
        #expect(outflow.amount == -100)
        #expect(inflow.amount == 100)
        #expect(outflow.isTransferLeg)
        #expect(inflow.isTransferLeg)
        #expect(outflow.transferID == inflow.transferID)
        #expect(outflow.status == .uncleared)
        #expect(inflow.status == .uncleared)
    }

    @Test("clears only the context leg of a cleared transfer")
    func recordsClearedTransfer() async throws {
        let sut = try await SUT()

        try await sut.commands.recordDetails(
            accountID: sut.seedAccount.id,
            details: sut.details(amount: -100, cleared: true, counterpartAccountID: sut.seedCounterpart.id)
        )

        let outflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id).first)
        let inflow = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedCounterpart.id).first)
        #expect(outflow.status == .cleared)
        #expect(inflow.status == .uncleared)
    }

    @Test("fails for an unknown account on the regular path")
    func failsForUnknownAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.recordDetails(accountID: UUID(), details: sut.details(amount: 10))
        }
    }

    @Test("fails for an unknown counterpart on the transfer path")
    func failsForUnknownCounterpart() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.recordDetails(
                accountID: sut.seedAccount.id,
                details: sut.details(amount: -10, counterpartAccountID: UUID())
            )
        }
    }

    @Test("fails on a closed account")
    func failsOnClosedAccount() async throws {
        let sut = try await SUT()
        var closed = sut.seedAccount
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            try await sut.commands.recordDetails(accountID: sut.seedAccount.id, details: sut.details(amount: 10))
        }
    }
}
