import Foundation

public struct Transfer: Versioned, Sendable {
    public let id: UUID
    public var version: Int = 0
    public let fromAccountID: UUID
    public let toAccountID: UUID
    public private(set) var amount: Decimal
    public private(set) var date: AcornDate
    public private(set) var fromStatus: TransactionStatus
    public private(set) var toStatus: TransactionStatus
    public private(set) var isDeleted: Bool

    public static func create(
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) throws -> Transfer {
        guard fromAccountID != toAccountID else {
            throw DomainError.invalidArgument("source and destination must differ")
        }
        guard amount > 0 else {
            throw DomainError.invalidArgument("amount must be positive")
        }
        return Transfer(
            id: UUID(),
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            amount: amount,
            date: date,
            fromStatus: .uncleared,
            toStatus: .uncleared,
            isDeleted: false
        )
    }

    public static func rehydrate(
        id: UUID,
        version: Int,
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate,
        fromStatus: TransactionStatus,
        toStatus: TransactionStatus,
        isDeleted: Bool
    ) -> Transfer {
        Transfer(
            id: id,
            version: version,
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            amount: amount,
            date: date,
            fromStatus: fromStatus,
            toStatus: toStatus,
            isDeleted: isDeleted
        )
    }

    public mutating func update(amount: Decimal, date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard amount > 0 else {
            throw DomainError.invalidArgument("amount must be positive")
        }
        self.amount = amount
        self.date = date
    }

    public mutating func clear(side: TransferSide) throws {
        guard !isDeleted else { throw DomainError.deleted }
        try mutateStatus(side: side) { status in
            guard status == .uncleared else {
                throw DomainError.invalidState("transfer side is not uncleared")
            }
            status = .cleared
        }
    }

    public mutating func unclear(side: TransferSide) throws {
        guard !isDeleted else { throw DomainError.deleted }
        try mutateStatus(side: side) { status in
            guard status == .cleared else {
                throw DomainError.invalidState("transfer side is not cleared")
            }
            status = .uncleared
        }
    }

    public mutating func reconcile(side: TransferSide) throws {
        guard !isDeleted else { throw DomainError.deleted }
        try mutateStatus(side: side) { status in
            guard status == .cleared else {
                throw DomainError.invalidState("transfer side is not cleared")
            }
            status = .reconciled
        }
    }

    public mutating func delete() throws {
        guard !isDeleted else { throw DomainError.deleted }
        isDeleted = true
    }

    public mutating func undelete() {
        isDeleted = false
    }

    private mutating func mutateStatus(
        side: TransferSide,
        _ body: (inout TransactionStatus) throws -> Void
    ) throws {
        switch side {
        case .from: try body(&fromStatus)
        case .to:   try body(&toStatus)
        }
    }
}

public enum TransferSide: Sendable, Equatable {
    case from
    case to
}
