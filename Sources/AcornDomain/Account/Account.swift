import Foundation

public struct Account: Versioned, Sendable {
    public let id: UUID
    public var version: Int = 0
    public private(set) var name: String
    public private(set) var notes: String
    public private(set) var isClosed: Bool = false
    public private(set) var isDeleted: Bool = false

    public static func rehydrate(
        id: UUID,
        version: Int,
        name: String,
        notes: String,
        isClosed: Bool,
        isDeleted: Bool
    ) -> Account {
        Account(
            id: id,
            version: version,
            name: name,
            notes: notes,
            isClosed: isClosed,
            isDeleted: isDeleted
        )
    }

    package func assertPostable() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard !isClosed else { throw DomainError.invalidState("account is closed") }
    }

    package static func make(name: String, notes: String) throws -> Account {
        guard let name = AccountValidation.normalizedName(name) else {
            throw DomainError.invalidArgument("name must not be blank")
        }
        return Account(
            id: UUID(),
            name: name,
            notes: notes
        )
    }

    package mutating func close() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard !isClosed else { throw DomainError.invalidState("account is already closed") }
        isClosed = true
    }

    package mutating func reopen() throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard isClosed else { throw DomainError.invalidState("account is not closed") }
        isClosed = false
    }

    package mutating func update(name: String, notes: String) throws {
        guard !isDeleted else { throw DomainError.deleted }
        guard let normalized = AccountValidation.normalizedName(name) else {
            throw DomainError.invalidArgument("name must not be blank")
        }
        self.name = normalized
        self.notes = notes
    }

    package mutating func delete() throws {
        guard !isDeleted else { throw DomainError.deleted }
        isDeleted = true
    }

    package mutating func undelete() {
        isDeleted = false
    }
}
