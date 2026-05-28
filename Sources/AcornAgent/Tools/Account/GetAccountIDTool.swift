import Foundation
import JSONSchema
import AcornApplication

private struct Input: Decodable { let name: String }

extension Tool {
    public static func getAccountID(_ queries: AccountQueries) -> Tool {
        Tool(
            name: "get_account_id",
            description: """
                Resolve an account name to its UUID (case-insensitive exact match). \
                Returns {id} on a single match; returns {ambiguous: [...]} with the \
                candidates if multiple accounts share the name — ask the user to \
                disambiguate in that case. Errors when no account matches.
                """,
            schema: .object(
                properties: [
                    "name": .string(description: "Account name to look up.")
                ],
                required: ["name"]
            ),
            invoke: { args in
                let data = try JSONEncoder().encode(args)
                let input = try JSONDecoder().decode(Input.self, from: data)
                let result = try await queries.getID(name: input.name)
                switch result {
                case .found(let id):
                    return .object(["id": .string(id.uuidString)])
                case .ambiguous(let candidates):
                    let dtos = candidates.map(AccountDTO.init(from:))
                    let data = try JSONEncoder().encode(dtos)
                    let json = try JSONDecoder().decode(JSONValue.self, from: data)
                    return .object(["ambiguous": json])
                }
            }
        )
    }
}
