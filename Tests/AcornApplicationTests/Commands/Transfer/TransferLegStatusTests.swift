import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

/// Transfer legs are plain transactions, so their cleared/uncleared/reconciled
/// status is driven through the regular transaction use cases — one leg at a
/// time, independently of its counterpart.
@Suite("TransferLegStatus")
struct TransferLegStatusTests {
    private struct SUT {
        let uow: InMemoryUnitOfWork
        let transactions: InMemoryTransactionRepository
        let transferCommands: TransferCommands
        let transactionCommands: TransactionCommands
        let seedFrom: Account
        let seedTo: Account

        init() async throws {
            let accounts = InMemoryAccountRepository()
            let transactions = InMemoryTransactionRepository()
            let uow = InMemoryUnitOfWork(accounts: accounts, transactions: transactions)
            self.uow = uow
            self.transactions = transactions
            self.transferCommands = TransferCommands(unitOfWork: uow)
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
    }

    @Test("clearing one leg leaves the counterpart untouched")
    func clearsOneLegIndependently() async throws {
        let sut = try await SUT()
        let legs = try await sut.transferCommands.record(
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
