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

    public static func add(
        accountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) -> Transaction {
        Transaction(
            id: UUID(),
            accountID: accountID,
            amount: amount,
            date: date,
            status: .uncleared,
            kind: .regular
        )
    }

    public static func adjust(
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

    public mutating func update(amount: Decimal, date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        self.amount = amount
        self.date = date
    }

    public mutating func delete() throws {
        guard !isDeleted else { throw DomainError.deleted }
        isDeleted = true
    }

    public mutating func undelete() {
        isDeleted = false
    }

    public mutating func reconcile() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard status == .cleared else {
            throw DomainError.invalidState("transaction is not cleared")
        }
        status = .reconciled
    }

    public mutating func clear() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard status == .uncleared else {
            throw DomainError.invalidState("transaction is not uncleared")
        }
        status = .cleared
    }

    public mutating func unclear() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard status == .cleared else {
            throw DomainError.invalidState("transaction is not cleared")
        }
        status = .uncleared
    }
}

public enum TransactionStatus: Sendable {
    case uncleared, cleared, reconciled
}

public enum TransactionKind: Sendable, Equatable {
    case regular
    case adjustment
}
