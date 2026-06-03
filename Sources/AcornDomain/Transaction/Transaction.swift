import Foundation

public struct Transaction: Versioned, Sendable {
    public let id: UUID
    public var version: Int = 0
    public let accountID: UUID
    public private(set) var lines: [TransactionLine]
    public private(set) var date: AcornDate
    public private(set) var status: TransactionStatus
    public let kind: TransactionKind
    public private(set) var isDeleted: Bool = false

    /// The transaction total — the sum of its lines.
    public var amount: Decimal { lines.reduce(0) { $0 + $1.amount } }

    /// Whether the transaction is split across more than one line.
    public var isSplit: Bool { lines.count > 1 }

    public static func rehydrate(
        id: UUID,
        version: Int,
        accountID: UUID,
        lines: [TransactionLine],
        date: AcornDate,
        status: TransactionStatus,
        kind: TransactionKind,
        isDeleted: Bool
    ) -> Transaction {
        Transaction(
            id: id,
            version: version,
            accountID: accountID,
            lines: lines,
            date: date,
            status: status,
            kind: kind,
            isDeleted: isDeleted
        )
    }

    package static func add(
        accountID: UUID,
        amount: Decimal,
        date: AcornDate,
        cleared: Bool = false
    ) -> Transaction {
        Transaction(
            id: UUID(),
            accountID: accountID,
            lines: [TransactionLine(amount: amount)],
            date: date,
            status: cleared ? .cleared : .uncleared,
            kind: .regular
        )
    }

    package static func adjust(
        accountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) throws -> Transaction {
        guard amount != 0 else {
            throw DomainError.invalidArgument("amount must be non-zero")
        }
        return Transaction(
            id: UUID(),
            accountID: accountID,
            lines: [TransactionLine(amount: amount)],
            date: date,
            status: .uncleared,
            kind: .adjustment
        )
    }

    /// Builds a split transaction by dividing `amount` across `lineAmounts`.
    ///
    /// - Throws: if fewer than two lines are given, any line amount is zero, or the lines do not
    ///   sum to `amount`.
    package static func split(
        accountID: UUID,
        amount: Decimal,
        date: AcornDate,
        cleared: Bool = false,
        lineAmounts: [Decimal]
    ) throws -> Transaction {
        try validateSplit(lineAmounts, total: amount)
        return Transaction(
            id: UUID(),
            accountID: accountID,
            lines: lineAmounts.map { TransactionLine(amount: $0) },
            date: date,
            status: cleared ? .cleared : .uncleared,
            kind: .regular
        )
    }

    private static func validateSplit(_ lineAmounts: [Decimal], total: Decimal) throws {
        guard lineAmounts.count >= 2 else {
            throw DomainError.invalidArgument("a split needs at least two lines")
        }
        guard lineAmounts.allSatisfy({ $0 != 0 }) else {
            throw DomainError.invalidArgument("split line amounts must be non-zero")
        }
        guard lineAmounts.reduce(0, +) == total else {
            throw DomainError.invalidArgument("split lines must sum to the transaction amount")
        }
    }

    /// Builds the two mirrored legs of a transfer: an outflow on the source
    /// account and an inflow on the destination, linked by a shared transfer id.
    package static func transfer(
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate,
        clearedAccountID: UUID? = nil
    ) throws -> (from: Transaction, to: Transaction) {
        guard fromAccountID != toAccountID else {
            throw DomainError.invalidArgument("source and destination must differ")
        }
        guard amount > 0 else {
            throw DomainError.invalidArgument("amount must be positive")
        }
        let transferID = UUID()
        let from = Transaction(
            id: UUID(),
            accountID: fromAccountID,
            lines: [TransactionLine(amount: -amount)],
            date: date,
            status: fromAccountID == clearedAccountID ? .cleared : .uncleared,
            kind: .transfer(id: transferID, counterpartAccountID: toAccountID)
        )
        let to = Transaction(
            id: UUID(),
            accountID: toAccountID,
            lines: [TransactionLine(amount: amount)],
            date: date,
            status: toAccountID == clearedAccountID ? .cleared : .uncleared,
            kind: .transfer(id: transferID, counterpartAccountID: fromAccountID)
        )
        return (from, to)
    }

    public var transferID: UUID? {
        if case let .transfer(id, _) = kind { return id }
        return nil
    }

    public var counterpartAccountID: UUID? {
        if case let .transfer(_, counterpartAccountID) = kind { return counterpartAccountID }
        return nil
    }

    public var isTransferLeg: Bool {
        if case .transfer = kind { return true }
        return false
    }

    /// Changes the amount and date of a single-line transaction.
    ///
    /// - Throws: if the transaction is deleted or split.
    package mutating func update(amount: Decimal, date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard !isSplit else { throw DomainError.invalidState("transaction is split") }
        lines[0].amount = amount
        self.date = date
    }

    /// Replaces a transaction's lines by dividing `amount` across `lineAmounts`, making it a split,
    /// and sets its date.
    ///
    /// - Throws: if the transaction is deleted, fewer than two lines are given, any line amount is
    ///   zero, or the lines do not sum to `amount`.
    package mutating func reviseSplit(amount: Decimal, lineAmounts: [Decimal], date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        try Self.validateSplit(lineAmounts, total: amount)
        lines = lineAmounts.map { TransactionLine(amount: $0) }
        self.date = date
    }

    /// Changes a transaction's date, leaving its lines untouched.
    ///
    /// - Throws: if the transaction is deleted.
    package mutating func setDate(_ date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        self.date = date
    }

    /// Revises a transfer leg from the transfer's positive magnitude, keeping the
    /// leg's outflow/inflow direction.
    package mutating func reviseTransferLeg(amount: Decimal, date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard amount > 0 else {
            throw DomainError.invalidArgument("amount must be positive")
        }
        lines[0].amount = lines[0].amount < 0 ? -amount : amount
        self.date = date
    }

    package mutating func delete() throws {
        guard !isDeleted else { throw DomainError.deleted }
        isDeleted = true
    }

    package mutating func undelete() {
        isDeleted = false
    }

    package mutating func reconcile() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard status == .cleared else {
            throw DomainError.invalidState("transaction is not cleared")
        }
        status = .reconciled
    }

    package mutating func clear() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard status == .uncleared else {
            throw DomainError.invalidState("transaction is not uncleared")
        }
        status = .cleared
    }

    package mutating func unclear() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard status == .cleared else {
            throw DomainError.invalidState("transaction is not cleared")
        }
        status = .uncleared
    }

    package mutating func setCleared(_ cleared: Bool) throws {
        switch (status, cleared) {
        case (.uncleared, true): try clear()
        case (.cleared, false): try unclear()
        default: break
        }
    }
}

public enum TransactionStatus: Codable, Sendable {
    case uncleared, cleared, reconciled
}

public enum TransactionKind: Codable, Equatable, Sendable {
    case regular
    case adjustment
    case transfer(id: UUID, counterpartAccountID: UUID)
}
