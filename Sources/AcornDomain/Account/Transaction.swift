import Foundation

public struct Transaction: Sendable {
    public let id: UUID
    public let accountID: UUID
    public let amount: Decimal
    public let date: AcornDate
    public let status: TransactionStatus
    public let kind: TransactionKind
    public let isDeleted: Bool

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

    public func updated(amount: Decimal, date: AcornDate) -> Transaction {
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

    public func deleted() -> Transaction {
        Transaction(
            id: id,
            accountID: accountID,
            amount: amount,
            date: date,
            status: status,
            kind: kind,
            isDeleted: true
        )
    }

    public func reconciled() -> Transaction {
        Transaction(
            id: id,
            accountID: accountID,
            amount: amount,
            date: date,
            status: .reconciled,
            kind: kind,
            isDeleted: isDeleted
        )
    }

    public func cleared() -> Transaction {
        Transaction(
            id: id,
            accountID: accountID,
            amount: amount,
            date: date,
            status: .cleared,
            kind: kind,
            isDeleted: isDeleted
        )
    }

    public func uncleared() -> Transaction {
        Transaction(
            id: id,
            accountID: accountID,
            amount: amount,
            date: date,
            status: .uncleared,
            kind: kind,
            isDeleted: isDeleted
        )
    }

    public func undeleted() -> Transaction {
        Transaction(
            id: id,
            accountID: accountID,
            amount: amount,
            date: date,
            status: status,
            kind: kind,
            isDeleted: false
        )
    }
}

public enum TransactionStatus: Sendable {
    case uncleared, cleared, reconciled
}

public enum TransactionKind: Sendable {
    case regular, adjustment, starting
    // TODO: transfer
}
