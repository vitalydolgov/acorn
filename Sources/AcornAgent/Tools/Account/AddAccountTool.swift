import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let name: String
    let notes: String?
}

extension Tool {
    public static func addAccount(_ command: AddAccount) -> Tool {
        Tool(
            name: "add_account",
            description: """
                Add a new account with the given name and optional notes. \
                Returns the created account's id, name, and is_closed flag — \
                use the id for subsequent operations.
                """,
            schema: .object(
                properties: [
                    "name": .string(description: "Name for the new account. Must not be blank."),
                    "notes": .string(description: "Optional free-form notes for the account.")
                ],
                required: ["name"]
            ),
            invoke: { args in
                let data = try JSONEncoder().encode(args)
                let input = try JSONDecoder().decode(Input.self, from: data)
                let account = try await command(name: input.name, notes: input.notes ?? "")
                let json = try JSONEncoder().encode(AccountDTO(from: account))
                return try JSONDecoder().decode(JSONValue.self, from: json)
            }
        )
    }
}
