import Foundation
import JSONSchema
import AcornDomain

public protocol AgentTool: Sendable {
    var name: String { get }
    var description: String { get }
    var schema: JSONSchema { get }
    func invoke(_ args: JSONValue) async throws -> JSONValue
}

// MARK: - Helpers

enum AgentToolError: Error {
    case invalidDate(String)
    case invalidDecimal(String)
}

func parseDate(_ string: String) throws -> AcornDate {
    let parts = string.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3,
          let date = AcornDate(year: parts[0], month: parts[1], day: parts[2])
    else {
        throw AgentToolError.invalidDate(string)
    }
    return date
}

func parseDecimal(_ string: String) throws -> Decimal {
    guard let value = Decimal(string: string) else {
        throw AgentToolError.invalidDecimal(string)
    }
    return value
}
