import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let accountID: UUID
    let notes: String
    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case notes
    }
}

extension Tool {
    public static func updateAccountMetadata(_ command: UpdateAccountMetadata) -> Tool {
        Tool(
            name: "update_account_metadata",
            description: """
                Update an account's notes. Pass an empty string to clear the notes.
                """,
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
                let data = try JSONEncoder().encode(args)
                let input = try JSONDecoder().decode(Input.self, from: data)
                try await command(accountID: input.accountID, notes: input.notes)
                return .object(["ok": .bool(true)])
            }
        )
    }
}
