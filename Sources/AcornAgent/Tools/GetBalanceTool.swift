import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let accountID: UUID
    enum CodingKeys: String, CodingKey { case accountID = "account_id" }
}

extension Tool {
    public static func getBalance(_ command: GetBalance) -> Tool {
        Tool(
            name: "get_balance",
            description: """
                Compute the current balance for an account — the sum of all \
                non-deleted transactions plus net transfers in and out. The \
                balance is returned as a decimal string to preserve precision.
                """,
            inputSchema: .object(
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
                let balance = try await command(accountID: input.accountID)
                return .object([
                    "balance": .string(NSDecimalNumber(decimal: balance).stringValue)
                ])
            }
        )
    }
}
