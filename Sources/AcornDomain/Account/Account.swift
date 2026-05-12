import Foundation

public struct Account: Sendable {
    public let id: UUID
    public let name: String
    public let notes: String
    public let isClosed: Bool
    public let isDeleted: Bool

    public static func make(name: String, notes: String) -> Account? {
        guard let name = AccountValidation.normalizedName(name) else { return nil }
        return Account(
            id: UUID(),
            name: name,
            notes: notes,
            isClosed: false,
            isDeleted: false
        )
    }

    public static func rehydrate(
        id: UUID,
        name: String,
        notes: String,
        isClosed: Bool,
        isDeleted: Bool
    ) -> Account {
        Account(
            id: id,
            name: name,
            notes: notes,
            isClosed: isClosed,
            isDeleted: isDeleted
        )
    }

    public func closed() -> Account {
        Account(
            id: id,
            name: name,
            notes: notes,
            isClosed: true,
            isDeleted: isDeleted
        )
    }

    public func reopened() -> Account {
        Account(
            id: id,
            name: name,
            notes: notes,
            isClosed: false,
            isDeleted: isDeleted
        )
    }

    public func updated(name: String, notes: String) -> Account? {
        guard let name = AccountValidation.normalizedName(name) else { return nil }
        return Account(
            id: id,
            name: name,
            notes: notes,
            isClosed: isClosed,
            isDeleted: isDeleted
        )
    }

    public func deleted() -> Account {
        Account(
            id: id,
            name: name,
            notes: notes,
            isClosed: isClosed,
            isDeleted: true
        )
    }

    public func undeleted() -> Account {
        Account(
            id: id,
            name: name,
            notes: notes,
            isClosed: isClosed,
            isDeleted: false
        )
    }
}
