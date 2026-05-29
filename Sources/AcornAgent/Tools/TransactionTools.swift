import Foundation
import JSONSchema
import AcornApplication
import AcornDomain

struct TransactionDTO: Encodable {
    let id: UUID
    let accountID: UUID
    let amount: String
    let date: String
    let status: String
    let isTransferLeg: Bool
    let transferID: UUID?
    let counterpartAccountID: UUID?

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
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, date, status
        case accountID = "account_id"
        case isTransferLeg = "is_transfer_leg"
        case transferID = "transfer_id"
        case counterpartAccountID = "counterpart_account_id"
    }
}

public struct TransactionTools: Sendable {
    private let commands: TransactionCommands
    private let queries: TransactionQueries

    public init(unitOfWork: any UnitOfWork) {
        self.commands = TransactionCommands(unitOfWork: unitOfWork)
        self.queries = TransactionQueries(unitOfWork: unitOfWork)
    }

    var all: [Tool] {
        [
            recordTransaction,
            getTransaction,
            listTransactions,
            changeTransactionAmount,
            changeTransactionDate,
            changeTransactionDetails,
            clearTransaction,
            unclearTransaction,
            reconcileTransaction,
            deleteTransaction
        ]
    }

    private var recordTransaction: Tool {
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
        return Tool(
            name: "record_transaction",
            description: """
                Record a transaction against an open account. \
                Returns the created transaction's id, account_id, amount, date, and status.
                """,
            schema: .object(
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
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                let tx = try await commands.record(
                    accountID: input.accountID,
                    amount: try parseDecimal(input.amount),
                    date: try parseDate(input.date),
                    cleared: input.cleared
                )
                return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(TransactionDTO(from: tx)))
            }
        )
    }

    private var getTransaction: Tool {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        return Tool(
            name: "get_transaction",
            description: "Get a single non-deleted transaction by id.",
            schema: .object(
                properties: [
                    "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
                ],
                required: ["transaction_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                let tx = try await queries.get(transactionID: input.transactionID)
                return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(TransactionDTO(from: tx)))
            }
        )
    }

    private var listTransactions: Tool {
        struct Input: Decodable {
            let accountID: UUID
            enum CodingKeys: String, CodingKey { case accountID = "account_id" }
        }
        return Tool(
            name: "list_transactions",
            description: """
                List all active (non-deleted) transactions for an account, sorted by date descending. \
                Returns id, account_id, amount, date, status, and transfer metadata for each entry. \
                Use this to discover what transactions exist before editing or deleting them.
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
                let transactions = try await queries.list(accountID: input.accountID)
                return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(transactions.map(TransactionDTO.init(from:))))
            }
        )
    }

    private var changeTransactionAmount: Tool {
        struct Input: Decodable {
            let transactionID: UUID
            let amount: String
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id"; case amount }
        }
        return Tool(
            name: "change_transaction_amount",
            description: "Change the amount of a regular (non-transfer) transaction.",
            schema: .object(
                properties: [
                    "transaction_id": .string(description: "UUID of the transaction.", format: .uuid),
                    "amount": .string(
                        description: "New signed decimal amount: positive for inflow, negative for outflow."
                    )
                ],
                required: ["transaction_id", "amount"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.changeAmount(transactionID: input.transactionID, amount: try parseDecimal(input.amount))
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var changeTransactionDate: Tool {
        struct Input: Decodable {
            let transactionID: UUID
            let date: String
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id"; case date }
        }
        return Tool(
            name: "change_transaction_date",
            description: "Change the date of a regular (non-transfer) transaction.",
            schema: .object(
                properties: [
                    "transaction_id": .string(description: "UUID of the transaction.", format: .uuid),
                    "date": .string(description: "New date in YYYY-MM-DD format.")
                ],
                required: ["transaction_id", "date"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.changeDate(transactionID: input.transactionID, date: try parseDate(input.date))
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var changeTransactionDetails: Tool {
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
        return Tool(
            name: "change_transaction_details",
            description: """
                Edit a transaction's amount, date, and cleared state. \
                If counterpart_account_id is provided the transaction is replaced with a transfer \
                to/from that account. Rejects transfer legs — use change_transfer_details instead.
                """,
            schema: .object(
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
            ),
            invoke: { args in
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
        )
    }

    private var clearTransaction: Tool {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        return Tool(
            name: "clear_transaction",
            description: "Mark an uncleared transaction as cleared.",
            schema: .object(
                properties: [
                    "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
                ],
                required: ["transaction_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.clear(transactionID: input.transactionID)
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var unclearTransaction: Tool {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        return Tool(
            name: "unclear_transaction",
            description: "Revert a cleared transaction back to uncleared.",
            schema: .object(
                properties: [
                    "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
                ],
                required: ["transaction_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.unclear(transactionID: input.transactionID)
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var reconcileTransaction: Tool {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        return Tool(
            name: "reconcile_transaction",
            description: "Promote a cleared transaction to reconciled. Fails if the transaction is not cleared.",
            schema: .object(
                properties: [
                    "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
                ],
                required: ["transaction_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.reconcile(transactionID: input.transactionID)
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var deleteTransaction: Tool {
        struct Input: Decodable {
            let transactionID: UUID
            enum CodingKeys: String, CodingKey { case transactionID = "transaction_id" }
        }
        return Tool(
            name: "delete_transaction",
            description: "Delete a regular (non-transfer) transaction. For transfers use delete_transfer.",
            schema: .object(
                properties: [
                    "transaction_id": .string(description: "UUID of the transaction.", format: .uuid)
                ],
                required: ["transaction_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.delete(transactionID: input.transactionID)
                return .object(["ok": .bool(true)])
            }
        )
    }
}
