import Foundation
import JSONSchema
import AcornApplication

extension Tool {
    public static func listAccounts(_ command: ListAccounts) -> Tool {
        Tool(
            name: "list_accounts",
            description: """
                List all non-deleted accounts (open and closed), with id, name, \
                and is_closed flag. Use this to discover what accounts exist or \
                to resolve a name when get_account_id reports ambiguity.
                """,
            inputSchema: .object(properties: [:], required: []),
            invoke: { _ in
                let accounts = try await command()
                let dtos = accounts.map(AccountDTO.init(from:))
                let data = try JSONEncoder().encode(dtos)
                return try JSONDecoder().decode(JSONValue.self, from: data)
            }
        )
    }
}
