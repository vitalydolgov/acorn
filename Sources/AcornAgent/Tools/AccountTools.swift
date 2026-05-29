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

    var all: [any AgentTool] { commandTools + queryTools }

    private var commandTools: [any AgentTool] {
        [
            AddAccount(commands: commands),
            AdjustBalance(commands: commands),
            ChangeAccountName(commands: commands),
            CloseAccount(commands: commands),
            DeleteAccount(commands: commands),
            ReopenAccount(commands: commands),
            UpdateAccountMetadata(commands: commands),
        ]
    }

    private var queryTools: [any AgentTool] {
        [
            ListAccounts(queries: queries),
            GetAccount(queries: queries),
            GetAccountID(queries: queries),
            CalculateBalance(queries: queries),
        ]
    }
}

private struct AddAccount: AgentTool {
    let commands: AccountCommands

    var name: String { "add_account" }
    var description: String {
        """
        Add a new account with the given name and optional notes. \
        Returns the created account's id, name, and is_closed flag — \
        use the id for subsequent operations.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "name": .string(description: "Name for the new account. Must not be blank."),
                "notes": .string(description: "Optional free-form notes for the account.")
            ],
            required: ["name"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let name: String
            let notes: String?
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let account = try await commands.add(name: input.name, notes: input.notes ?? "")
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(AccountDTO(from: account)))
    }
}

private struct AdjustBalance: AgentTool {
    let commands: AccountCommands

    var name: String { "adjust_balance" }
    var description: String {
        """
        Create an adjustment transaction on an account, dated today. \
        Use this to correct a balance discrepancy. \
        Returns the created transaction.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "account_id": .string(
                    description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                    format: .uuid
                ),
                "amount": .string(
                    description: "Signed decimal amount: positive for inflow, negative for outflow."
                )
            ],
            required: ["account_id", "amount"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            let amount: String
            enum CodingKeys: String, CodingKey { case accountID = "account_id"; case amount }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let tx = try await commands.adjustBalance(accountID: input.accountID, amount: try parseDecimal(input.amount))
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(TransactionDTO(from: tx)))
    }
}

private struct ListAccounts: AgentTool {
    let queries: AccountQueries

    var name: String { "list_accounts" }
    var description: String {
        """
        List all non-deleted accounts (open and closed), with id, name, \
        notes, and is_closed flag. Use this to discover what accounts \
        exist, to resolve a name when get_account_id reports ambiguity, \
        or to find an account by its notes/description when the user \
        refers to it by purpose or by a rule kept in its notes.
        """
    }
    var schema: JSONSchema { .object(properties: [:], required: []) }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        let accounts = try await queries.list()
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(accounts.map(AccountDTO.init(from:))))
    }
}

private struct GetAccount: AgentTool {
    let queries: AccountQueries

    var name: String { "get_account" }
    var description: String {
        """
        Get full information for a single account by id: name, notes, \
        and whether it is closed. Notes are a free-form description \
        that may contain user-defined rules not modelled elsewhere — \
        read them when the user refers to an account by what it is for. \
        Obtain the id via get_account_id or list_accounts.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "account_id": .string(
                    description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                    format: .uuid
                )
            ],
            required: ["account_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let account = try await queries.get(accountID: input.accountID)
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(AccountDTO(from: account)))
    }
}

private struct GetAccountID: AgentTool {
    let queries: AccountQueries

    var name: String { "get_account_id" }
    var description: String {
        """
        Resolve an account name to its UUID (case-insensitive exact match). \
        Returns {id} on a single match; returns {ambiguous: [...]} with the \
        candidates if multiple accounts share the name — ask the user to \
        disambiguate in that case. Errors when no account matches.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "name": .string(description: "Account name to look up.")
            ],
            required: ["name"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable { let name: String }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        switch try await queries.getID(name: input.name) {
        case .found(let id):
            return .object(["id": .string(id.uuidString)])
        case .ambiguous(let candidates):
            let value = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(candidates.map(AccountDTO.init(from:))))
            return .object(["ambiguous": value])
        }
    }
}

private struct CalculateBalance: AgentTool {
    let queries: AccountQueries

    var name: String { "calculate_balance" }
    var description: String {
        """
        Compute the balances for an account. Returns the working \
        balance (all non-deleted transactions plus net transfers), the \
        cleared balance (only cleared and reconciled activity), and the \
        uncleared balance (only uncleared activity); working equals \
        cleared plus uncleared. Each is a decimal string to preserve \
        precision.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "account_id": .string(
                    description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                    format: .uuid
                )
            ],
            required: ["account_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let balances = try await queries.calculateBalance(accountID: input.accountID)
        return .object([
            "cleared_balance": .string(NSDecimalNumber(decimal: balances.cleared).stringValue),
            "uncleared_balance": .string(NSDecimalNumber(decimal: balances.uncleared).stringValue),
            "working_balance": .string(NSDecimalNumber(decimal: balances.working).stringValue)
        ])
    }
}

private struct ChangeAccountName: AgentTool {
    let commands: AccountCommands

    var name: String { "change_account_name" }
    var description: String { "Rename an account. The name must not be blank." }
    var schema: JSONSchema {
        .object(
            properties: [
                "account_id": .string(
                    description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                    format: .uuid
                ),
                "name": .string(description: "New name for the account. Must not be blank.")
            ],
            required: ["account_id", "name"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            let name: String
            enum CodingKeys: String, CodingKey { case accountID = "account_id"; case name }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.changeName(accountID: input.accountID, name: input.name)
        return .object(["ok": .bool(true)])
    }
}

private struct CloseAccount: AgentTool {
    let commands: AccountCommands

    var name: String { "close_account" }
    var description: String {
        """
        Close an account. Any non-zero balance is zeroed out with an \
        adjustment transaction dated today before the account is \
        closed. Fails if the account is already closed.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "account_id": .string(
                    description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                    format: .uuid
                )
            ],
            required: ["account_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.close(accountID: input.accountID)
        return .object(["ok": .bool(true)])
    }
}

private struct DeleteAccount: AgentTool {
    let commands: AccountCommands

    var name: String { "delete_account" }
    var description: String {
        """
        Permanently delete an account. Fails if the account still has \
        any non-deleted transactions or transfers — close it instead \
        if it has activity.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "account_id": .string(
                    description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                    format: .uuid
                )
            ],
            required: ["account_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.delete(accountID: input.accountID)
        return .object(["ok": .bool(true)])
    }
}

private struct ReopenAccount: AgentTool {
    let commands: AccountCommands

    var name: String { "reopen_account" }
    var description: String { "Reopen a previously closed account. Fails if the account is not closed." }
    var schema: JSONSchema {
        .object(
            properties: [
                "account_id": .string(
                    description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                    format: .uuid
                )
            ],
            required: ["account_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.reopen(accountID: input.accountID)
        return .object(["ok": .bool(true)])
    }
}

private struct UpdateAccountMetadata: AgentTool {
    let commands: AccountCommands

    var name: String { "update_account_metadata" }
    var description: String { "Update an account's notes. Pass an empty string to clear the notes." }
    var schema: JSONSchema {
        .object(
            properties: [
                "account_id": .string(
                    description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                    format: .uuid
                ),
                "notes": .string(description: "New notes for the account. Pass an empty string to clear.")
            ],
            required: ["account_id", "notes"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            let notes: String
            enum CodingKeys: String, CodingKey { case accountID = "account_id"; case notes }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.updateMetadata(accountID: input.accountID, notes: input.notes)
        return .object(["ok": .bool(true)])
    }
}
