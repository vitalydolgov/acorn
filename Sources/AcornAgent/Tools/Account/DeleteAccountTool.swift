import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let accountID: UUID
    enum CodingKeys: String, CodingKey { case accountID = "account_id" }
}

extension Tool {
    public static func deleteAccount(_ commands: AccountCommands) -> Tool {
        Tool(
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
                let data = try JSONEncoder().encode(args)
                let input = try JSONDecoder().decode(Input.self, from: data)
                try await commands.delete(accountID: input.accountID)
                return .object(["ok": .bool(true)])
            }
        )
    }
}
