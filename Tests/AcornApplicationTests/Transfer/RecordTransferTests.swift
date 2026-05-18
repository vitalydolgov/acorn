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
        let transfers: InMemoryTransferRepository

        // Services
        let recordTransfer: RecordTransfer

        let seedFrom: Account
        let seedTo: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let transfers = InMemoryTransferRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions, transfers: transfers)
            self.uow = uow

            // Repos
            self.accounts = accounts
            self.transfers = transfers

            // Services
            self.recordTransfer = RecordTransfer(unitOfWork: uow)

            var from = try Account.make(name: "Checking", notes: "")
            var to = try Account.make(name: "Savings", notes: "")
            try await accounts.save(from)
            from = try await accounts.get(id: from.id)!
            try await accounts.save(to)
            to = try await accounts.get(id: to.id)!
            self.seedFrom = from
            self.seedTo = to
        }
    }

    private static let today = AcornDate.today()

    @Test("stores a single Transfer and balances the two accounts")
    func storesOneTransfer() async throws {
        let sut = try await SUT()

        let transfer = try await sut.recordTransfer(
            fromAccountID: sut.seedFrom.id,
            toAccountID: sut.seedTo.id,
            amount: 100,
            date: Self.today
        )

        let stored = try #require(try await sut.transfers.get(id: transfer.id))
        #expect(stored.fromAccountID == sut.seedFrom.id)
        #expect(stored.toAccountID == sut.seedTo.id)
        #expect(stored.amount == 100)

        let fromTransfers = try await sut.transfers.forAccount(sut.seedFrom.id)
        let toTransfers = try await sut.transfers.forAccount(sut.seedTo.id)
        #expect(fromTransfers.count == 1)
        #expect(toTransfers.count == 1)
        #expect(fromTransfers[0].id == toTransfers[0].id)

        #expect(
            BalanceCalculator.balance(
                transactions: [Transaction](),
                transfers: fromTransfers,
                accountID: sut.seedFrom.id
            ) == -100
        )
        #expect(
            BalanceCalculator.balance(
                transactions: [Transaction](),
                transfers: toTransfers,
                accountID: sut.seedTo.id
            ) == 100
        )
    }

    @Test("fails when source account is unknown")
    func failsForUnknownFrom() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.notFound) {
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
        await #expect(throws: ApplicationError.notFound) {
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
