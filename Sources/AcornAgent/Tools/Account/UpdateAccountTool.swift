import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let accountID: UUID
    let name: String?
    let notes: String?
    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case name, notes
    }
}

extension Tool {
    public static func updateAccount(_ command: UpdateAccount) -> Tool {
        Tool(
            name: "update_account",
            description: """
                Edit an account's details. Provide only the fields you want to \
                change: omit "name" to keep the current name, omit "notes" to \
                keep the current notes — you do not need to read the account \
                first. Pass "notes" as an empty string to clear it. Name must \
                not be blank if provided.
                """,
            schema: .object(
                properties: [
                    "account_id": .string(
                        description: "UUID of the account. Obtain via get_account_id or list_accounts.",
                        format: .uuid
                    ),
                    "name": .string(description: "New name for the account. Omit to keep it unchanged; must not be blank if given."),
                    "notes": .string(description: "New notes. Omit to keep unchanged; empty string clears the notes.")
                ],
                required: ["account_id"]
            ),
            invoke: { args in
                let data = try JSONEncoder().encode(args)
                let input = try JSONDecoder().decode(Input.self, from: data)
                try await command(
                    accountID: input.accountID,
                    name: input.name,
                    notes: input.notes
                )
                return .object(["ok": .bool(true)])
            }
        )
    }
}
