import Foundation
import JSONSchema
import AcornApplication
import AcornDomain

public struct TransferTools: Sendable {
    private let commands: TransferCommands
    private let queries: TransactionQueries

    public init(unitOfWork: any UnitOfWork) {
        self.commands = TransferCommands(unitOfWork: unitOfWork)
        self.queries = TransactionQueries(unitOfWork: unitOfWork)
    }

    var all: [Tool] {
        [
            recordTransfer,
            listTransferLegs,
            changeTransferDetails,
            deleteTransfer
        ]
    }

    private var recordTransfer: Tool {
        struct Input: Decodable {
            let fromAccountID: UUID
            let toAccountID: UUID
            let amount: String
            let date: String
            let clearedAccountID: UUID?
            enum CodingKeys: String, CodingKey {
                case fromAccountID = "from_account_id"
                case toAccountID = "to_account_id"
                case amount, date
                case clearedAccountID = "cleared_account_id"
            }
        }
        return Tool(
            name: "record_transfer",
            description: """
                Record a transfer between two distinct open accounts. \
                Amount must be positive (the magnitude moved). \
                Returns both legs: the outflow on from_account_id and the inflow on to_account_id.
                """,
            schema: .object(
                properties: [
                    "from_account_id": .string(description: "UUID of the source account.", format: .uuid),
                    "to_account_id": .string(description: "UUID of the destination account.", format: .uuid),
                    "amount": .string(description: "Positive decimal amount to transfer."),
                    "date": .string(description: "Transfer date in YYYY-MM-DD format."),
                    "cleared_account_id": .string(
                        description: "Optional. UUID of the account whose leg should be marked cleared immediately.",
                        format: .uuid
                    )
                ],
                required: ["from_account_id", "to_account_id", "amount", "date"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                let legs = try await commands.record(
                    fromAccountID: input.fromAccountID,
                    toAccountID: input.toAccountID,
                    amount: try parseDecimal(input.amount),
                    date: try parseDate(input.date),
                    clearedAccountID: input.clearedAccountID
                )
                return .object([
                    "from": try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(TransactionDTO(from: legs.from))),
                    "to": try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(TransactionDTO(from: legs.to)))
                ])
            }
        )
    }

    private var listTransferLegs: Tool {
        struct Input: Decodable {
            let transferID: UUID
            enum CodingKeys: String, CodingKey { case transferID = "transfer_id" }
        }
        return Tool(
            name: "list_transfer_legs",
            description: """
                Fetch both legs of a transfer by the shared transfer id. \
                Returns the outflow leg (negative amount) and the inflow leg (positive amount).
                """,
            schema: .object(
                properties: [
                    "transfer_id": .string(
                        description: "Transfer id shared by both legs (from the transfer_id field of either leg).",
                        format: .uuid
                    )
                ],
                required: ["transfer_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                let legs = try await queries.listTransferLegs(transferID: input.transferID)
                return try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(legs.map(TransactionDTO.init(from:))))
            }
        )
    }

    private var changeTransferDetails: Tool {
        struct Input: Decodable {
            let transferID: UUID
            let accountID: UUID
            let amount: String
            let date: String
            let cleared: Bool
            let counterpartAccountID: UUID?
            enum CodingKeys: String, CodingKey {
                case transferID = "transfer_id"
                case accountID = "account_id"
                case amount, date, cleared
                case counterpartAccountID = "counterpart_account_id"
            }
        }
        return Tool(
            name: "change_transfer_details",
            description: """
                Edit a transfer's amount, date, and cleared state from the perspective of one of its accounts. \
                If counterpart_account_id is omitted the transfer is replaced with a plain transaction on account_id. \
                The transfer_id is the shared id on both legs; find it in the transfer_id field of either leg.
                """,
            schema: .object(
                properties: [
                    "transfer_id": .string(
                        description: "Transfer id shared by both legs (from the transfer_id field of either leg).",
                        format: .uuid
                    ),
                    "account_id": .string(
                        description: "UUID of the account providing the context perspective.",
                        format: .uuid
                    ),
                    "amount": .string(
                        description: "Signed decimal amount from account_id's perspective: positive for inflow, negative for outflow."
                    ),
                    "date": .string(description: "Date in YYYY-MM-DD format."),
                    "cleared": .boolean(description: "Whether account_id's leg should be cleared."),
                    "counterpart_account_id": .string(
                        description: "Keep or change the counterpart. Omit to replace the transfer with a regular transaction.",
                        format: .uuid
                    )
                ],
                required: ["transfer_id", "account_id", "amount", "date", "cleared"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                let details = TransactionDetails(
                    amount: try parseDecimal(input.amount),
                    date: try parseDate(input.date),
                    cleared: input.cleared,
                    counterpartAccountID: input.counterpartAccountID
                )
                try await commands.changeDetails(transferID: input.transferID, accountID: input.accountID, details: details)
                return .object(["ok": .bool(true)])
            }
        )
    }

    private var deleteTransfer: Tool {
        struct Input: Decodable {
            let transferID: UUID
            enum CodingKeys: String, CodingKey { case transferID = "transfer_id" }
        }
        return Tool(
            name: "delete_transfer",
            description: "Delete both legs of a transfer. For regular transactions use delete_transaction.",
            schema: .object(
                properties: [
                    "transfer_id": .string(
                        description: "Transfer id shared by both legs (from the transfer_id field of either leg).",
                        format: .uuid
                    )
                ],
                required: ["transfer_id"]
            ),
            invoke: { args in
                let input = try JSONDecoder().decode(Input.self, from: JSONEncoder().encode(args))
                try await commands.delete(transferID: input.transferID)
                return .object(["ok": .bool(true)])
            }
        )
    }
}
