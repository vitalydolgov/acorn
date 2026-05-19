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

    package static func create(
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

    package mutating func update(amount: Decimal, date: AcornDate) throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard amount > 0 else {
            throw DomainError.invalidArgument("amount must be positive")
        }
        self.amount = amount
        self.date = date
    }

    package mutating func clear(side: TransferSide) throws {
        guard !isDeleted else { throw DomainError.deleted }
        switch side {
        case .from:
            guard fromStatus == .uncleared else {
                throw DomainError.invalidState("transfer side is not uncleared")
            }
            fromStatus = .cleared
        case .to:
            guard toStatus == .uncleared else {
                throw DomainError.invalidState("transfer side is not uncleared")
            }
            toStatus = .cleared
        }
    }

    package mutating func unclear(side: TransferSide) throws {
        guard !isDeleted else { throw DomainError.deleted }
        switch side {
        case .from:
            guard fromStatus == .cleared else {
                throw DomainError.invalidState("transfer side is not cleared")
            }
            fromStatus = .uncleared
        case .to:
            guard toStatus == .cleared else {
                throw DomainError.invalidState("transfer side is not cleared")
            }
            toStatus = .uncleared
        }
    }

    package mutating func reconcile(side: TransferSide) throws {
        guard !isDeleted else { throw DomainError.deleted }
        switch side {
        case .from:
            guard fromStatus == .cleared else {
                throw DomainError.invalidState("transfer side is not cleared")
            }
            fromStatus = .reconciled
        case .to:
            guard toStatus == .cleared else {
                throw DomainError.invalidState("transfer side is not cleared")
            }
            toStatus = .reconciled
        }
    }

    package mutating func delete() throws {
        guard !isDeleted else { throw DomainError.deleted }
        isDeleted = true
    }

    package mutating func undelete() {
        isDeleted = false
    }
}

public enum TransferSide: Sendable {
    case from
    case to
}
