import Foundation

public struct Transaction: Sendable {
    public let id: UUID
    public let accountID: UUID
    public private(set) var amount: Decimal
    public private(set) var date: AcornDate
    public private(set) var status: TransactionStatus
    public let kind: TransactionKind
    public private(set) var isDeleted: Bool

    public static func post(
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
            kind: .regular,
            isDeleted: false
        )
    }

    public static func adjust(
        accountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) -> Transaction? {
        guard amount != 0 else { return nil }
        return Transaction(
            id: UUID(),
            accountID: accountID,
            amount: amount,
            date: date,
            status: .uncleared,
            kind: .adjustment,
            isDeleted: false
        )
    }

    public static func starting(
        accountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) -> Transaction? {
        guard amount != 0 else { return nil }
        return Transaction(
            id: UUID(),
            accountID: accountID,
            amount: amount,
            date: date,
            status: .cleared,
            kind: .starting,
            isDeleted: false
        )
    }

    public static func rehydrate(
        id: UUID,
        accountID: UUID,
        amount: Decimal,
        date: AcornDate,
        status: TransactionStatus,
        kind: TransactionKind,
        isDeleted: Bool
    ) -> Transaction {
        Transaction(
            id: id,
            accountID: accountID,
            amount: amount,
            date: date,
            status: status,
            kind: kind,
            isDeleted: isDeleted
        )
    }

    public mutating func update(amount: Decimal, date: AcornDate) {
        self.amount = amount
        self.date = date
    }

    public mutating func delete() {
        isDeleted = true
    }

    public mutating func undelete() {
        isDeleted = false
    }

    public mutating func reconcile() {
        status = .reconciled
    }

    public mutating func clear() {
        status = .cleared
    }

    public mutating func unclear() {
        status = .uncleared
    }
}

public enum TransactionStatus: Sendable {
    case uncleared, cleared, reconciled
}

public enum TransactionKind: Sendable {
    case regular, adjustment, starting
    // TODO: transfer
}
