import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let accountID: UUID
    enum CodingKeys: String, CodingKey { case accountID = "account_id" }
}

extension Tool {
    public static func calculateBalance(_ command: CalculateBalance) -> Tool {
        Tool(
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
                let data = try JSONEncoder().encode(args)
                let input = try JSONDecoder().decode(Input.self, from: data)
                let balances = try await command(accountID: input.accountID)
                return .object([
                    "cleared_balance": .string(NSDecimalNumber(decimal: balances.cleared).stringValue),
                    "uncleared_balance": .string(NSDecimalNumber(decimal: balances.uncleared).stringValue),
                    "working_balance": .string(NSDecimalNumber(decimal: balances.working).stringValue)
                ])
            }
        )
    }
}
