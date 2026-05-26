import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let accountID: UUID
    let name: String
    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case name
    }
}

extension Tool {
    public static func changeAccountName(_ command: ChangeAccountName) -> Tool {
        Tool(
            name: "change_account_name",
            description: """
                Rename an account. The name must not be blank.
                """,
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
                let data = try JSONEncoder().encode(args)
                let input = try JSONDecoder().decode(Input.self, from: data)
                try await command(accountID: input.accountID, name: input.name)
                return .object(["ok": .bool(true)])
            }
        )
    }
}
