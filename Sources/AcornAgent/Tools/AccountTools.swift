import Foundation
import JSONSchema
import AcornApplication
import AcornDomain

struct AccountDTO: Encodable {
    let id: UUID
    let name: String
    let notes: String
    let isClosed: Bool

    init(from account: Account) {
        self.id = account.id
        self.name = account.name
        self.notes = account.notes
        self.isClosed = account.isClosed
    }

    enum CodingKeys: String, CodingKey {
        case id, name, notes
        case isClosed = "is_closed"
    }
}

public struct AccountTools: Sendable {
    private let commands: AccountCommands
    private let queries: AccountQueries

    public init(unitOfWork: any UnitOfWork, todayProvider: any TodayProvider) {
        self.commands = AccountCommands(unitOfWork: unitOfWork, todayProvider: todayProvider)
        self.queries = AccountQueries(unitOfWork: unitOfWork)
    }

    var all: [Tool] {
        [
            addAccount,
            listAccounts,
            getAccount,
            getAccountID,
            calculateBalance,
            changeAccountName,
            closeAccount,
            deleteAccount,
            reopenAccount,
            updateAccountMetadata
        ]
    }

    private var addAccount: Tool {
        struct Input: Decodable {
            let name: String
            let notes: String?
        }
        return Tool(
            name: "add_account",
            description: """
                Add a new account with the given name and optional notes. \
                Returns the created account's id, name, and is_closed flag — \
                use the id for subsequent operations.
                """,
            schema: .object(
                properties: [
                    "name": .string(description: "Name for the new account. Must not be blank."),
                    "notes": .string(description: "Optional free-form notes for the account.")
                ],
                required: ["name"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                let account = try await commands.add(name: input.name, notes: input.notes ?? "")
                return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(AccountDTO(from: account)))
            }
        )
    }

    private var listAccounts: Tool {
        return Tool(
            name: "list_accounts",
            description: """
                List all non-deleted accounts (open and closed), with id, name, \
                notes, and is_closed flag. Use this to discover what accounts \
                exist, to resolve a name when get_account_id reports ambiguity, \
                or to find an account by its notes/description when the user \
                refers to it by purpose or by a rule kept in its notes.
                """,
            schema: .object(properties: [:], required: []),
            invoke: { _ in
                let accounts = try await queries.list()
                return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(accounts.map(AccountDTO.init(from:))))
            }
        )
    }

    private var getAccount: Tool {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        return Tool(
            name: "get_account",
            description: """
                Get full information for a single account by id: name, notes, \
                and whether it is closed. Notes are a free-form description \
                that may contain user-defined rules not modelled elsewhere — \
                read them when the user refers to an account by what it is for. \
                Obtain the id via get_account_id or list_accounts.
                """,
            schema: .object(
                properties: [
                    "account_id": .string(
                        description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                        format: .uuid
                    )
                ],
                required: ["account_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                let account = try await queries.get(accountID: input.accountID)
                return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(AccountDTO(from: account)))
            }
        )
    }

    private var getAccountID: Tool {
        struct Input: Decodable { let name: String }
        return Tool(
            name: "get_account_id",
            description: """
                Resolve an account name to its UUID (case-insensitive exact match). \
                Returns {id} on a single match; returns {ambiguous: [...]} with the \
                candidates if multiple accounts share the name — ask the user to \
                disambiguate in that case. Errors when no account matches.
                """,
            schema: .object(
                properties: [
                    "name": .string(description: "Account name to look up.")
                ],
                required: ["name"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                switch try await queries.getID(name: input.name) {
                case .found(let id):
                    return .object(["id": .string(id.uuidString)])
                case .ambiguous(let candidates):
                    let value = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(candidates.map(AccountDTO.init(from:))))
                    return .object(["ambiguous": value])
                }
            }
        )
    }

    private var calculateBalance: Tool {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        return Tool(
            name: "calculate_balance",
            description: """
                Compute the balances for an account. Returns the working \
                balance (all non-deleted transactions plus net transfers), the \
                cleared balance (only cleared and reconciled activity), and the \
                uncleared balance (only uncleared activity); working equals \
                cleared plus uncleared. Each is a decimal string to preserve \
                precision.
                """,
            schema: .object(
                properties: [
                    "account_id": .string(
                        description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                        format: .uuid
                    )
                ],
                required: ["account_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                let balances = try await queries.calculateBalance(accountID: input.accountID)
                return .object([
                    "cleared_balance": .string(NSDecimalNumber(decimal: balances.cleared).stringValue),
                    "uncleared_balance": .string(NSDecimalNumber(decimal: balances.uncleared).stringValue),
                    "working_balance": .string(NSDecimalNumber(decimal: balances.working).stringValue)
                ])
            }
        )
    }

    private var changeAccountName: Tool {
        struct Input: Decodable {
            let accountID: UUID
            let name: String
            enum CodingKeys: String, CodingKey { case accountID = "account_id"; case name }
        }
        return Tool(
            name: "change_account_name",
            description: "Rename an account. The name must not be blank.",
            schema: .object(
                properties: [
                    "account_id": .string(
                        description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                        format: .uuid
                    ),
                    "name": .string(description: "New name for the account. Must not be blank.")
                ],
                required: ["account_id", "name"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.changeName(accountID: input.accountID, name: input.name)
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var closeAccount: Tool {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        return Tool(
            name: "close_account",
            description: """
                Close an account. Any non-zero balance is zeroed out with an \
                adjustment transaction dated today before the account is \
                closed. Fails if the account is already closed.
                """,
            schema: .object(
                properties: [
                    "account_id": .string(
                        description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                        format: .uuid
                    )
                ],
                required: ["account_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.close(accountID: input.accountID)
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var deleteAccount: Tool {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        return Tool(
            name: "delete_account",
            description: """
                Permanently delete an account. Fails if the account still has \
                any non-deleted transactions or transfers — close it instead \
                if it has activity.
                """,
            schema: .object(
                properties: [
                    "account_id": .string(
                        description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                        format: .uuid
                    )
                ],
                required: ["account_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.delete(accountID: input.accountID)
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var reopenAccount: Tool {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        return Tool(
            name: "reopen_account",
            description: "Reopen a previously closed account. Fails if the account is not closed.",
            schema: .object(
                properties: [
                    "account_id": .string(
                        description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                        format: .uuid
                    )
                ],
                required: ["account_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.reopen(accountID: input.accountID)
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var updateAccountMetadata: Tool {
        struct Input: Decodable {
            let accountID: UUID
            let notes: String
            enum CodingKeys: String, CodingKey { case accountID = "account_id"; case notes }
        }
        return Tool(
            name: "update_account_metadata",
            description: "Update an account's notes. Pass an empty string to clear the notes.",
            schema: .object(
                properties: [
                    "account_id": .string(
                        description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                        format: .uuid
                    ),
                    "notes": .string(description: "New notes for the account. Pass an empty string to clear.")
                ],
                required: ["account_id", "notes"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.updateMetadata(accountID: input.accountID, notes: input.notes)
                return .object(["ok": .bool(true)])
            }
        )
    }
}
