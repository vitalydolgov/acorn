import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable {
    let accountID: UUID
    enum CodingKeys: String, CodingKey { case accountID = "account_id" }
}

extension Tool {
    public static func getAccount(_ command: GetAccount) -> Tool {
        Tool(
            name: "get_account",
            description: """
                Get full information for a single account by id: name, notes, \
                and whether it is closed. Notes are a free-form description \
                that may contain user-defined rules not modelled elsewhere — \
                read them when the user refers to an account by what it is for. \
                Obtain the id via get_account_id or list_accounts.
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
                let account = try await command(accountID: input.accountID)
                let json = try JSONEncoder().encode(AccountDTO(from: account))
                return try JSONDecoder().decode(JSONValue.self, from: json)
            }
        )
    }
}
