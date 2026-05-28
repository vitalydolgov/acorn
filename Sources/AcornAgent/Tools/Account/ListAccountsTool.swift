import Foundation
import JSONSchema
import AcornApplication

extension Tool {
    public static func listAccounts(_ queries: AccountQueries) -> Tool {
        Tool(
            name: "list_accounts",
            description: """
                List all non-deleted accounts (open and closed), with id, name, \
                notes, and is_closed flag. Use this to discover what accounts \
                exist, to resolve a name when get_account_id reports ambiguity, \
                or to find an account by its notes/description when the user \
                refers to it by purpose or by a rule kept in its notes.
                """,
            schema: .object(properties: [:], required: []),
            invoke: { _ in
                let accounts = try await queries.list()
                let dtos = accounts.map(AccountDTO.init(from:))
                let data = try JSONEncoder().encode(dtos)
                return try JSONDecoder().decode(JSONValue.self, from: data)
            }
        )
    }
}
