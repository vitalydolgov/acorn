import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let accountID: UUID
    enum CodingKeys: String, CodingKey { case accountID = "account_id" }
}

extension Tool {
    public static func closeAccount(_ command: CloseAccount) -> Tool {
        Tool(
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
                let data = try JSONEncoder().encode(args)
                let input = try JSONDecoder().decode(Input.self, from: data)
                try await command(accountID: input.accountID)
                return .object(["ok": .bool(true)])
            }
        )
    }
}
