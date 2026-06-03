import Foundation
import JSONSchema
import AcornApplication
import AcornDomain

struct TransactionLineDTO: Encodable {
    let id: UUID
    let amount: String

    init(from line: TransactionLine) {
        self.id = line.id
        self.amount = NSDecimalNumber(decimal: line.amount).stringValue
    }
}

struct TransactionDTO: Encodable {
    let id: UUID
    let accountID: UUID
    let amount: String
    let date: String
    let status: String
    let isTransferLeg: Bool
    let transferID: UUID?
    let counterpartAccountID: UUID?
    let isSplit: Bool
    let lines: [TransactionLineDTO]

    init(from transaction: Transaction) {
        self.id = transaction.id
        self.accountID = transaction.accountID
        self.amount = NSDecimalNumber(decimal: transaction.amount).stringValue
        let d = transaction.date
        self.date = String(format: "%04d-%02d-%02d", d.year, d.month, d.day)
        switch transaction.status {
        case .uncleared:  self.status = "uncleared"
        case .cleared:    self.status = "cleared"
        case .reconciled: self.status = "reconciled"
        }
        self.isTransferLeg = transaction.isTransferLeg
        self.transferID = transaction.transferID
        self.counterpartAccountID = transaction.counterpartAccountID
        self.isSplit = transaction.isSplit
        self.lines = transaction.lines.map(TransactionLineDTO.init(from:))
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, date, status, lines
        case accountID = "account_id"
        case isTransferLeg = "is_transfer_leg"
        case transferID = "transfer_id"
        case counterpartAccountID = "counterpart_account_id"
        case isSplit = "is_split"
    }
}

public struct TransactionTools: Sendable {
    private let commands: TransactionCommands
    private let queries: TransactionQueries
    
    public init(unitOfWork: any UnitOfWork) {
        self.commands = TransactionCommands(unitOfWork: unitOfWork)
        self.queries = TransactionQueries(unitOfWork: unitOfWork)
    }
    
    var all: [any AgentTool] { commandTools + queryTools }
    
    private var commandTools: [any AgentTool] {
        [
            RecordTransaction(commands: commands),
            RecordDetails(commands: commands),
            RecordSplit(commands: commands),
            ChangeSplit(commands: commands),
            ChangeTransactionAmount(commands: commands),
            ChangeTransactionDate(commands: commands),
            ChangeTransactionDetails(commands: commands),
            ClearTransaction(commands: commands),
            UnclearTransaction(commands: commands),
            ReconcileTransaction(commands: commands),
            DeleteTransaction(commands: commands),
        ]
    }
    
    private var queryTools: [any AgentTool] {
        [
            GetTransaction(queries: queries),
            ListTransactions(queries: queries),
        ]
    }
}

private struct RecordTransaction: AgentTool {
    let commands: TransactionCommands

    var name: String { "record_transaction" }
    var description: String {
        """
        Record a transaction against an open account. \
        Returns the created transaction's id, account_id, amount, date, and status.
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
                    description: "Signed decimal amount: positive for inflow, negative for outflow. E.g. \"-42.50\"."
                ),
                "date": .string(description: "Transaction date in YYYY-MM-DD format."),
                "cleared": .boolean(description: "Pass true if the transaction is already cleared.")
            ],
            required: ["account_id", "amount", "date", "cleared"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            let amount: String
            let date: String
            let cleared: Bool
            enum CodingKeys: String, CodingKey {
                case accountID = "account_id"
                case amount, date, cleared
            }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let tx = try await commands.record(
            accountID: input.accountID,
            amount: try parseDecimal(input.amount),
            date: try parseDate(input.date),
            cleared: input.cleared
        )
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(TransactionDTO(from: tx)))
    }
}

private struct RecordDetails: AgentTool {
    let commands: TransactionCommands

    var name: String { "record_details" }
    var description: String {
        """
        Record a transaction or transfer from account_id's perspective. \
        If counterpart_account_id is provided a transfer is created; \
        otherwise a plain transaction is recorded. \
        The amount is signed from account_id's perspective: positive for inflow, negative for outflow.
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
                    description: "Signed decimal amount from account_id's perspective: positive for inflow, negative for outflow."
                ),
                "date": .string(description: "Date in YYYY-MM-DD format."),
                "cleared": .boolean(description: "Whether the transaction should be cleared."),
                "counterpart_account_id": .string(
                    description: "Set to record as a transfer with this counterpart account. Omit for a plain transaction.",
                    format: .uuid
                )
            ],
            required: ["account_id", "amount", "date", "cleared"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let accountID: UUID
            let amount: String
            let date: String
            let cleared: Bool
            let counterpartAccountID: UUID?
            enum CodingKeys: String, CodingKey {
                case accountID = "account_id"
                case amount, date, cleared
                case counterpartAccountID = "counterpart_account_id"
            }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let details = TransactionDetails(
            amount: try parseDecimal(input.amount),
            date: try parseDate(input.date),
            cleared: input.cleared,
            counterpartAccountID: input.counterpartAccountID
        )
        try await commands.recordDetails(accountID: input.accountID, details: details)
        return .object(["ok": .bool(true)])
    }
}

private struct RecordSplit: AgentTool {
    let commands: TransactionCommands

    var name: String { "record_split" }
    var description: String {
        """
        Record a split transaction against an open account: one transaction whose total is divided \
        across two or more lines. Provide the transaction amount (the total) and at least two \
        non-zero line amounts that must sum to it. Returns the created transaction including its lines.
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
                    description: "Signed decimal transaction total; the lines must sum to this. E.g. \"-100.00\"."
                ),
                "lines": .array(
                    description: "Two or more split lines summing to amount. Each is signed: positive inflow, negative outflow.",
                    items: .object(
                        properties: [
                            "amount": .string(description: "Signed decimal amount, e.g. \"-42.50\".")
                        ],
                        required: ["amount"]
                    ),
                    minItems: 2
                ),
                "date": .string(description: "Transaction date in YYYY-MM-DD format."),
                "cleared": .boolean(description: "Pass true if the transaction is already cleared.")
            ],
            required: ["account_id", "amount", "lines", "date", "cleared"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Line: Decodable { let amount: String }
        struct Input: Decodable {
            let accountID: UUID
            let amount: String
            let lines: [Line]
            let date: String
            let cleared: Bool
            enum CodingKeys: String, CodingKey {
                case accountID = "account_id"
                case amount, lines, date, cleared
            }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let tx = try await commands.recordSplit(
            accountID: input.accountID,
            amount: try parseDecimal(input.amount),
            lineAmounts: try input.lines.map { try parseDecimal($0.amount) },
            date: try parseDate(input.date),
            cleared: input.cleared
        )
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(TransactionDTO(from: tx)))
    }
}

private struct ChangeSplit: AgentTool {
    let commands: TransactionCommands

    var name: String { "change_split" }
    var description: String {
        """
        Replace a transaction's lines, date, and cleared state, making it a split. \
        Provide the transaction amount (the total) and at least two non-zero line amounts that must \
        sum to it. Rejects transfer legs.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid),
                "amount": .string(
                    description: "Signed decimal transaction total; the lines must sum to this. E.g. \"-100.00\"."
                ),
                "lines": .array(
                    description: "Two or more split lines summing to amount. Each is signed: positive inflow, negative outflow.",
                    items: .object(
                        properties: [
                            "amount": .string(description: "Signed decimal amount, e.g. \"-42.50\".")
                        ],
                        required: ["amount"]
                    ),
                    minItems: 2
                ),
                "date": .string(description: "Date in YYYY-MM-DD format."),
                "cleared": .boolean(description: "Cleared state.")
            ],
            required: ["transaction_id", "amount", "lines", "date", "cleared"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Line: Decodable { let amount: String }
        struct Input: Decodable {
            let transactionID: UUID
            let amount: String
            let lines: [Line]
            let date: String
            let cleared: Bool
            enum CodingKeys: String, CodingKey {
                case transactionID = "transaction_id"
                case amount, lines, date, cleared
            }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.changeSplit(
            transactionID: input.transactionID,
            amount: try parseDecimal(input.amount),
            lineAmounts: try input.lines.map { try parseDecimal($0.amount) },
            date: try parseDate(input.date),
            cleared: input.cleared
        )
        return .object(["ok": .bool(true)])
    }
}

private struct GetTransaction: AgentTool {
    let queries: TransactionQueries

    var name: String { "get_transaction" }
    var description: String { "Get a single non-deleted transaction by id." }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
            ],
            required: ["transaction_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let tx = try await queries.get(transactionID: input.transactionID)
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(TransactionDTO(from: tx)))
    }
}

private struct ListTransactions: AgentTool {
    let queries: TransactionQueries

    var name: String { "list_transactions" }
    var description: String {
        """
        List all active (non-deleted) transactions for an account, sorted by date descending. \
        Returns id, account_id, amount, date, status, and transfer metadata for each entry. \
        Use this to discover what transactions exist before editing or deleting them.
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
        let transactions = try await queries.list(accountID: input.accountID)
        return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(transactions.map(TransactionDTO.init(from:))))
    }
}

private struct ChangeTransactionAmount: AgentTool {
    let commands: TransactionCommands

    var name: String { "change_transaction_amount" }
    var description: String { "Change the amount of a regular (non-transfer, non-split) transaction. For splits use change_split." }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid),
                "amount": .string(
                    description: "New signed decimal amount: positive for inflow, negative for outflow."
                )
            ],
            required: ["transaction_id", "amount"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let transactionID: UUID
            let amount: String
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id"; case amount }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.changeAmount(transactionID: input.transactionID, amount: try parseDecimal(input.amount))
        return .object(["ok": .bool(true)])
    }
}

private struct ChangeTransactionDate: AgentTool {
    let commands: TransactionCommands

    var name: String { "change_transaction_date" }
    var description: String { "Change the date of a regular (non-transfer) transaction." }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid),
                "date": .string(description: "New date in YYYY-MM-DD format.")
            ],
            required: ["transaction_id", "date"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let transactionID: UUID
            let date: String
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id"; case date }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.changeDate(transactionID: input.transactionID, date: try parseDate(input.date))
        return .object(["ok": .bool(true)])
    }
}

private struct ChangeTransactionDetails: AgentTool {
    let commands: TransactionCommands

    var name: String { "change_transaction_details" }
    var description: String {
        """
        Edit a transaction's amount, date, and cleared state. \
        If counterpart_account_id is provided the transaction is replaced with a transfer \
        to/from that account. Rejects transfer legs — use change_transfer_details instead — \
        and splits — use change_split instead.
        """
    }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid),
                "amount": .string(
                    description: "Signed decimal amount: positive for inflow, negative for outflow."
                ),
                "date": .string(description: "Date in YYYY-MM-DD format."),
                "cleared": .boolean(description: "Cleared state."),
                "counterpart_account_id": .string(
                    description: "Set to convert to a transfer with this counterpart account. Omit to keep as a regular transaction.",
                    format: .uuid
                )
            ],
            required: ["transaction_id", "amount", "date", "cleared"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let transactionID: UUID
            let amount: String
            let date: String
            let cleared: Bool
            let counterpartAccountID: UUID?
            enum CodingKeys: String, CodingKey {
                case transactionID = "transaction_id"
                case amount, date, cleared
                case counterpartAccountID = "counterpart_account_id"
            }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        let details = TransactionDetails(
            amount: try parseDecimal(input.amount),
            date: try parseDate(input.date),
            cleared: input.cleared,
            counterpartAccountID: input.counterpartAccountID
        )
        try await commands.changeDetails(transactionID: input.transactionID, details: details)
        return .object(["ok": .bool(true)])
    }
}

private struct ClearTransaction: AgentTool {
    let commands: TransactionCommands

    var name: String { "clear_transaction" }
    var description: String { "Mark an uncleared transaction as cleared." }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
            ],
            required: ["transaction_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.clear(transactionID: input.transactionID)
        return .object(["ok": .bool(true)])
    }
}

private struct UnclearTransaction: AgentTool {
    let commands: TransactionCommands

    var name: String { "unclear_transaction" }
    var description: String { "Revert a cleared transaction back to uncleared." }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
            ],
            required: ["transaction_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.unclear(transactionID: input.transactionID)
        return .object(["ok": .bool(true)])
    }
}

private struct ReconcileTransaction: AgentTool {
    let commands: TransactionCommands

    var name: String { "reconcile_transaction" }
    var description: String { "Promote a cleared transaction to reconciled. Fails if the transaction is not cleared." }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
            ],
            required: ["transaction_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.reconcile(transactionID: input.transactionID)
        return .object(["ok": .bool(true)])
    }
}

private struct DeleteTransaction: AgentTool {
    let commands: TransactionCommands

    var name: String { "delete_transaction" }
    var description: String { "Delete a regular (non-transfer) transaction. For transfers use delete_transfer." }
    var schema: JSONSchema {
        .object(
            properties: [
                "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
            ],
            required: ["transaction_id"]
        )
    }

    func invoke(_ args: JSONValue) async throws -> JSONValue {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
        try await commands.delete(transactionID: input.transactionID)
        return .object(["ok": .bool(true)])
    }
}
