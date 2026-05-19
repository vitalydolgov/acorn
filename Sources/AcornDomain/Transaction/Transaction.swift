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

    package mutating func update(amount: Decimal, date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        self.amount = amount
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
}

public enum TransactionStatus: Codable, Sendable {
    case uncleared, cleared, reconciled
}

public enum TransactionKind: Codable, Equatable, Sendable {
    case regular
    case adjustment
}
