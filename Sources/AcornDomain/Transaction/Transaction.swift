import Foundation

public struct Transaction: Versioned, Sendable {
    public let id: UUID
    public var version: Int = 0
    public let accountID: UUID
    public private(set) var amount: Decimal
    public private(set) var date: AcornDate
    public private(set) var status: TransactionStatus
    public let kind: TransactionKind
    public private(set) var isDeleted: Bool = false

    public static func rehydrate(
        id: UUID,
        version: Int,
        accountID: UUID,
        amount: Decimal,
        date: AcornDate,
        status: TransactionStatus,
        kind: TransactionKind,
        isDeleted: Bool
    ) -> Transaction {
        Transaction(
            id: id,
            version: version,
            accountID: accountID,
            amount: amount,
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
            amount: amount,
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
            amount: amount,
            date: date,
            status: .uncleared,
            kind: .adjustment
        )
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
            amount: -amount,
            date: date,
            status: fromAccountID == clearedAccountID ? .cleared : .uncleared,
            kind: .transfer(id: transferID, counterpartAccountID: toAccountID)
        )
        let to = Transaction(
            id: UUID(),
            accountID: toAccountID,
            amount: amount,
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

    package mutating func update(amount: Decimal, date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        self.amount = amount
        self.date = date
    }

    /// Revises a transfer leg from the transfer's positive magnitude, keeping the
    /// leg's outflow/inflow direction.
    package mutating func reviseTransferLeg(amount: Decimal, date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard amount > 0 else {
            throw DomainError.invalidArgument("amount must be positive")
        }
        self.amount = self.amount < 0 ? -amount : amount
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
