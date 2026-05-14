import Foundation

public struct Account: Sendable {
    public let id: UUID
    public private(set) var name: String
    public private(set) var notes: String
    public private(set) var isClosed: Bool
    public private(set) var isDeleted: Bool

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

    public mutating func close() {
        isClosed = true
    }

    public mutating func reopen() {
        isClosed = false
    }

    public mutating func update(name: String, notes: String) throws {
        guard let normalized = AccountValidation.normalizedName(name) else {
            throw DomainError.invalidArgument("name")
        }
        self.name = normalized
        self.notes = notes
    }

    public mutating func delete() {
        isDeleted = true
    }

    public mutating func undelete() {
        isDeleted = false
    }
}
