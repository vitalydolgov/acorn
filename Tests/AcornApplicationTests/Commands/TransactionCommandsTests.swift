import Foundation
import Testing
@testable import AcornApplication
import AcornInMemory
import AcornDomain

@Suite("TransactionCommands")
struct TransactionCommandsTests {
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

        func post(_ amount: Decimal = 10) async throws -> Transaction {
            try await commands.record(accountID: seedAccount.id, amount: amount, date: .today())
        }

        func details(
            amount: Decimal,
            cleared: Bool = false,
            counterpartAccountID: UUID? = nil
        ) -> TransactionDetails {
            TransactionDetails(
                amount: amount,
                date: TransactionCommandsTests.today,
                cleared: cleared,
                counterpartAccountID: counterpartAccountID
            )
        }
    }

    private static let today = AcornDate.today()

    // MARK: - changeAmount

    @Test("updates amount, preserving date")
    func changeAmountUpdatesAmount() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)

        try await sut.commands.changeAmount(transactionID: tx.id, amount: 25)

        let stored = try await sut.transactions.fetch(id: tx.id)
        #expect(stored?.amount == 25)
        #expect(stored?.date == Self.today)
    }

    @Test("fails for unknown transaction")
    func changeAmountFailsForUnknown() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeAmount(transactionID: UUID(), amount: 1)
        }
    }

    @Test("fails on a deleted transaction")
    func changeAmountFailsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        var deletedTx = try await sut.transactions.fetch(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.changeAmount(transactionID: tx.id, amount: 99)
        }
    }

    @Test("rejects editing a transfer leg directly")
    func changeAmountRejectsTransferLeg() async throws {
        let sut = try await SUT()
        let legs = try Transaction.transfer(
            fromAccountID: sut.seedAccount.id,
            toAccountID: UUID(),
            amount: 10,
            date: Self.today
        )
        try await sut.transactions.save(legs.from)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeAmount(transactionID: legs.from.id, amount: 5)
        }
    }

    // MARK: - changeDate

    @Test("updates date, preserving amount")
    func changeDateUpdatesDate() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        let newDate = Self.today.adding(days: 1)

        try await sut.commands.changeDate(transactionID: tx.id, date: newDate)

        let stored = try await sut.transactions.fetch(id: tx.id)
        #expect(stored?.amount == 10)
        #expect(stored?.date == newDate)
    }

    @Test("fails for unknown transaction")
    func changeDateFailsForUnknown() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDate(transactionID: UUID(), date: Self.today)
        }
    }

    @Test("fails on a deleted transaction")
    func changeDateFailsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        var deletedTx = try await sut.transactions.fetch(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.changeDate(transactionID: tx.id, date: Self.today)
        }
    }

    @Test("rejects editing a transfer leg directly")
    func changeDateRejectsTransferLeg() async throws {
        let sut = try await SUT()
        let legs = try Transaction.transfer(
            fromAccountID: sut.seedAccount.id,
            toAccountID: UUID(),
            amount: 10,
            date: Self.today
        )
        try await sut.transactions.save(legs.from)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDate(transactionID: legs.from.id, date: Self.today)
        }
    }

    // MARK: - changeDetails

    @Test("edits a regular transaction in place when no counterpart")
    func changeDetailsEditsInPlace() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)

        try await sut.commands.changeDetails(transactionID: tx.id, details: sut.details(amount: 25))

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.amount == 25)
        #expect(stored.isDeleted == false)
        #expect(stored.kind == .regular)
        let active = try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id)
        #expect(active.count == 1)
    }

    @Test("toggles cleared state in place")
    func changeDetailsTogglesCleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)

        try await sut.commands.changeDetails(transactionID: tx.id, details: sut.details(amount: 10, cleared: true))

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.status == .cleared)
    }

    @Test("converts a regular transaction into a transfer when a counterpart is given")
    func changeDetailsConvertsToTransfer() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -100, date: Self.today)

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
    func changeDetailsConvertsClearedToTransfer() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -100, date: Self.today)

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
    func changeDetailsRejectsTransferLeg() async throws {
        let sut = try await SUT()
        let legs = try Transaction.transfer(
            fromAccountID: sut.seedAccount.id,
            toAccountID: sut.seedCounterpart.id,
            amount: 10,
            date: Self.today
        )
        try await sut.transactions.save(legs.from)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDetails(transactionID: legs.from.id, details: sut.details(amount: 5))
        }
    }

    @Test("fails for unknown transaction")
    func changeDetailsFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDetails(transactionID: UUID(), details: sut.details(amount: 5))
        }
    }

    @Test("rolls back the conversion when the counterpart account is unknown")
    func changeDetailsRollsBackOnUnknownCounterpart() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -100, date: Self.today)

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

    // MARK: - clear

    @Test("flips uncleared to cleared")
    func clearFlipsUnclearedToCleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()

        try await sut.commands.clear(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.status == .cleared)
    }

    @Test("fails when not uncleared")
    func clearFailsWhenNotUncleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.commands.clear(transactionID: tx.id)

        await #expect(throws: DomainError.invalidState("transaction is not uncleared")) {
            try await sut.commands.clear(transactionID: tx.id)
        }
    }

    @Test("fails for unknown transaction")
    func clearFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.clear(transactionID: UUID())
        }
    }

    @Test("fails on a deleted transaction")
    func clearFailsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        var deletedTx = try await sut.transactions.fetch(id: tx.id)!
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.clear(transactionID: tx.id)
        }
    }

    // MARK: - delete

    @Test("marks transaction deleted")
    func deleteMarksDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()

        try await sut.commands.delete(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.isDeleted == true)
    }

    @Test("fails when already deleted")
    func deleteFailsWhenAlreadyDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.commands.delete(transactionID: tx.id)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.delete(transactionID: tx.id)
        }
    }

    @Test("rejects deleting a transfer leg directly")
    func deleteRejectsTransferLeg() async throws {
        let sut = try await SUT()
        let legs = try Transaction.transfer(
            fromAccountID: sut.seedAccount.id,
            toAccountID: UUID(),
            amount: 10,
            date: .today()
        )
        try await sut.transactions.save(legs.from)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.delete(transactionID: legs.from.id)
        }
    }

    // MARK: - reconcile

    @Test("promotes cleared to reconciled")
    func reconcilePromotesClearedToReconciled() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.commands.clear(transactionID: tx.id)

        try await sut.commands.reconcile(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.status == .reconciled)
    }

    @Test("fails on uncleared")
    func reconcileFailsOnUncleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()

        await #expect(throws: DomainError.invalidState("transaction is not cleared")) {
            try await sut.commands.reconcile(transactionID: tx.id)
        }
    }

    @Test("fails for unknown transaction")
    func reconcileFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.reconcile(transactionID: UUID())
        }
    }

    @Test("fails on a deleted transaction")
    func reconcileFailsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.commands.clear(transactionID: tx.id)
        let cleared = try #require(try await sut.transactions.fetch(id: tx.id))
        var deletedTx = cleared
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.reconcile(transactionID: tx.id)
        }
    }

    // MARK: - record

    @Test("stores a regular transaction with the given signed amount")
    func recordStoresSignedAmount() async throws {
        let sut = try await SUT()

        let inflow = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 50, date: Self.today)
        #expect(inflow.amount == 50)
        #expect(inflow.kind == .regular)
        let storedIn = try await sut.transactions.fetch(id: inflow.id)
        #expect(storedIn?.amount == 50)

        let outflow = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -30, date: Self.today)
        #expect(outflow.amount == -30)
        #expect(outflow.kind == .regular)
    }

    @Test("fails for unknown account")
    func recordFailsForUnknownAccount() async throws {
        let sut = try await SUT()

        await #expect(throws: ApplicationError.self) {
            _ = try await sut.commands.record(accountID: UUID(), amount: 10, date: Self.today)
        }
    }

    @Test("fails on a closed account")
    func recordFailsOnClosedAccount() async throws {
        let sut = try await SUT()
        var closed = sut.seedAccount
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        }
    }

    @Test("fails on a deleted account")
    func recordFailsOnDeletedAccount() async throws {
        let sut = try await SUT()
        var deleted = sut.seedAccount
        try deleted.delete()
        try await sut.accounts.save(deleted)

        await #expect(throws: DomainError.deleted) {
            _ = try await sut.commands.record(accountID: sut.seedAccount.id, amount: 10, date: Self.today)
        }
    }

    // MARK: - recordDetails

    @Test("records a regular transaction when no counterpart is given")
    func recordDetailsRecordsRegular() async throws {
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
    func recordDetailsRecordsClearedRegular() async throws {
        let sut = try await SUT()

        try await sut.commands.recordDetails(accountID: sut.seedAccount.id, details: sut.details(amount: 50, cleared: true))

        let tx = try #require(try await sut.transactions.fetchActive(forAccount: sut.seedAccount.id).first)
        #expect(tx.status == .cleared)
    }

    @Test("records a transfer when a counterpart is given")
    func recordDetailsRecordsTransfer() async throws {
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
    func recordDetailsRecordsClearedTransfer() async throws {
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
    func recordDetailsFailsForUnknownAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.recordDetails(accountID: UUID(), details: sut.details(amount: 10))
        }
    }

    @Test("fails for an unknown counterpart on the transfer path")
    func recordDetailsFailsForUnknownCounterpart() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.recordDetails(
                accountID: sut.seedAccount.id,
                details: sut.details(amount: -10, counterpartAccountID: UUID())
            )
        }
    }

    @Test("fails on a closed account")
    func recordDetailsFailsOnClosedAccount() async throws {
        let sut = try await SUT()
        var closed = sut.seedAccount
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            try await sut.commands.recordDetails(accountID: sut.seedAccount.id, details: sut.details(amount: 10))
        }
    }

    // MARK: - unclear

    @Test("flips cleared to uncleared")
    func unclearFlipsClearedToUncleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.commands.clear(transactionID: tx.id)

        try await sut.commands.unclear(transactionID: tx.id)

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.status == .uncleared)
    }

    @Test("fails when not cleared")
    func unclearFailsWhenNotCleared() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()

        await #expect(throws: DomainError.invalidState("transaction is not cleared")) {
            try await sut.commands.unclear(transactionID: tx.id)
        }
    }

    @Test("fails on reconciled")
    func unclearFailsOnReconciled() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.commands.clear(transactionID: tx.id)
        try await sut.commands.reconcile(transactionID: tx.id)

        await #expect(throws: DomainError.invalidState("transaction is not cleared")) {
            try await sut.commands.unclear(transactionID: tx.id)
        }
    }

    @Test("fails for unknown transaction")
    func unclearFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.unclear(transactionID: UUID())
        }
    }

    @Test("fails on a deleted transaction")
    func unclearFailsOnDeleted() async throws {
        let sut = try await SUT()
        let tx = try await sut.post()
        try await sut.commands.clear(transactionID: tx.id)
        let cleared = try #require(try await sut.transactions.fetch(id: tx.id))
        var deletedTx = cleared
        try deletedTx.delete()
        try await sut.transactions.save(deletedTx)

        await #expect(throws: DomainError.deleted) {
            try await sut.commands.unclear(transactionID: tx.id)
        }
    }

    // MARK: - recordSplit

    @Test("records a split dividing the amount across its lines")
    func recordSplitRecordsSplit() async throws {
        let sut = try await SUT()

        let tx = try await sut.commands.recordSplit(
            accountID: sut.seedAccount.id,
            amount: -100,
            lineAmounts: [-60, -40],
            date: Self.today
        )

        #expect(tx.isSplit)
        #expect(tx.amount == -100)
        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.lines.count == 2)
        #expect(stored.amount == -100)
        #expect(stored.kind == .regular)
    }

    @Test("records a cleared split")
    func recordSplitRecordsCleared() async throws {
        let sut = try await SUT()

        let tx = try await sut.commands.recordSplit(
            accountID: sut.seedAccount.id,
            amount: 30,
            lineAmounts: [10, 20],
            date: Self.today,
            cleared: true
        )

        #expect(tx.status == .cleared)
    }

    @Test("fails for an unknown account")
    func recordSplitFailsForUnknownAccount() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            _ = try await sut.commands.recordSplit(accountID: UUID(), amount: 3, lineAmounts: [1, 2], date: Self.today)
        }
    }

    @Test("fails on a closed account")
    func recordSplitFailsOnClosedAccount() async throws {
        let sut = try await SUT()
        var closed = sut.seedAccount
        try closed.close()
        try await sut.accounts.save(closed)

        await #expect(throws: DomainError.invalidState("account is closed")) {
            _ = try await sut.commands.recordSplit(accountID: sut.seedAccount.id, amount: 3, lineAmounts: [1, 2], date: Self.today)
        }
    }

    @Test("rejects fewer than two lines")
    func recordSplitRejectsTooFewLines() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("a split needs at least two lines")) {
            _ = try await sut.commands.recordSplit(accountID: sut.seedAccount.id, amount: 10, lineAmounts: [10], date: Self.today)
        }
    }

    @Test("rejects lines that do not sum to the amount")
    func recordSplitRejectsUnbalancedLines() async throws {
        let sut = try await SUT()
        await #expect(throws: DomainError.invalidArgument("split lines must sum to the transaction amount")) {
            _ = try await sut.commands.recordSplit(accountID: sut.seedAccount.id, amount: -100, lineAmounts: [-60, -30], date: Self.today)
        }
    }

    // MARK: - changeSplit

    @Test("turns a regular transaction into a split")
    func changeSplitConvertsRegular() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -100, date: Self.today)

        try await sut.commands.changeSplit(
            transactionID: tx.id,
            amount: -100,
            lineAmounts: [-60, -40],
            date: Self.today,
            cleared: false
        )

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.isSplit)
        #expect(stored.lines.count == 2)
        #expect(stored.amount == -100)
    }

    @Test("revises an existing split and its cleared state")
    func changeSplitRevisesSplit() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.recordSplit(
            accountID: sut.seedAccount.id,
            amount: -100,
            lineAmounts: [-60, -40],
            date: Self.today
        )

        try await sut.commands.changeSplit(
            transactionID: tx.id,
            amount: -100,
            lineAmounts: [-20, -30, -50],
            date: Self.today,
            cleared: true
        )

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.lines.count == 3)
        #expect(stored.amount == -100)
        #expect(stored.status == .cleared)
    }

    @Test("rejects lines that do not sum to the amount")
    func changeSplitRejectsUnbalancedLines() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.record(accountID: sut.seedAccount.id, amount: -100, date: Self.today)

        await #expect(throws: DomainError.invalidArgument("split lines must sum to the transaction amount")) {
            try await sut.commands.changeSplit(transactionID: tx.id, amount: -100, lineAmounts: [-60, -30], date: Self.today, cleared: false)
        }
    }

    @Test("fails for unknown transaction")
    func changeSplitFailsForUnknown() async throws {
        let sut = try await SUT()
        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeSplit(transactionID: UUID(), amount: 3, lineAmounts: [1, 2], date: Self.today, cleared: false)
        }
    }

    @Test("rejects editing a transfer leg directly")
    func changeSplitRejectsTransferLeg() async throws {
        let sut = try await SUT()
        let legs = try Transaction.transfer(
            fromAccountID: sut.seedAccount.id,
            toAccountID: UUID(),
            amount: 10,
            date: Self.today
        )
        try await sut.transactions.save(legs.from)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeSplit(transactionID: legs.from.id, amount: 3, lineAmounts: [1, 2], date: Self.today, cleared: false)
        }
    }

    // MARK: - split rejection by single-amount editors

    @Test("changeAmount rejects a split")
    func changeAmountRejectsSplit() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.recordSplit(accountID: sut.seedAccount.id, amount: 3, lineAmounts: [1, 2], date: Self.today)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeAmount(transactionID: tx.id, amount: 5)
        }
    }

    @Test("changeDetails rejects a split")
    func changeDetailsRejectsSplit() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.recordSplit(accountID: sut.seedAccount.id, amount: 3, lineAmounts: [1, 2], date: Self.today)

        await #expect(throws: ApplicationError.self) {
            try await sut.commands.changeDetails(transactionID: tx.id, details: sut.details(amount: 5))
        }
    }

    @Test("changeDate moves a split without touching its lines")
    func changeDateMovesSplit() async throws {
        let sut = try await SUT()
        let tx = try await sut.commands.recordSplit(accountID: sut.seedAccount.id, amount: 10, lineAmounts: [3, 7], date: Self.today)
        let newDate = Self.today.adding(days: 3)

        try await sut.commands.changeDate(transactionID: tx.id, date: newDate)

        let stored = try #require(try await sut.transactions.fetch(id: tx.id))
        #expect(stored.date == newDate)
        #expect(stored.lines.count == 2)
        #expect(stored.amount == 10)
    }
}
