import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("RecordTransfer")
struct RecordTransferTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork

        // Repos
        let accounts: InMemoryAccountRepository
        let transactions: InMemoryTransactionRepository

        // Services
        let recordTransfer: RecordTransfer

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

            // Services
            self.recordTransfer = RecordTransfer(unitOfWork: uow)

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

    @Test("stores two mirrored legs that balance the two accounts")
    func storesTwoLegs() async throws {
        let sut = try await SUT()

        let legs = try await sut.recordTransfer(
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
    func failsForUnknownFrom() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.recordTransfer(
                fromAccountID: UUID(),
                toAccountID: sut.seedTo.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails when destination account is unknown")
    func failsForUnknownTo() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.recordTransfer(
                fromAccountID: sut.seedFrom.id,
                toAccountID: UUID(),
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails on a closed account")
    func failsOnClosed() async throws {
        let sut = try await SUT()
        var closed = sut.seedFrom
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.recordTransfer(
                fromAccountID: sut.seedFrom.id,
                toAccountID: sut.seedTo.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails on a deleted account")
    func failsOnDeleted() async throws {
        let sut = try await SUT()
        var deleted = sut.seedTo
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            _ = try await sut.recordTransfer(
                fromAccountID: sut.seedFrom.id,
                toAccountID: sut.seedTo.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails when accounts are the same")
    func failsForSameAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("source and destination must differ")) {
            _ = try await sut.recordTransfer(
                fromAccountID: sut.seedFrom.id,
                toAccountID: sut.seedFrom.id,
                amount: 10,
                date: Self.today
            )
        }
    }

    @Test("fails for non-positive amount")
    func failsForNonPositive() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("amount must be positive")) {
            _ = try await sut.recordTransfer(
                fromAccountID: sut.seedFrom.id,
                toAccountID: sut.seedTo.id,
                amount: 0,
                date: Self.today
            )
        }
    }
}
