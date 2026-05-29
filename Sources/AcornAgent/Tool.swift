import Foundation
import JSONSchema
import AcornDomain

public struct Tool: Sendable {
    public let name: String
    public let description: String
    public let schema: JSONSchema
    public let invoke: @Sendable (JSONValue) async throws -> JSONValue

    public init(
        name: String,
        description: String,
        schema: JSONSchema,
        invoke: @Sendable @escaping (JSONValue) async throws -> JSONValue
    ) {
        self.name = name
        self.description = description
        self.schema = schema
        self.invoke = invoke
    }

    public var descriptor: ToolDescriptor {
        ToolDescriptor(name: name, description: description, schema: schema)
    }
}

public struct ToolDescriptor: Encodable, Sendable {
    public let name: String
    public let description: String
    public let schema: JSONSchema

    public init(name: String, description: String, schema: JSONSchema) {
        self.name = name
        self.description = description
        self.schema = schema
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case schema = "input_schema"
    }
}

public actor ToolCatalog {
    private var tools: [String: Tool] = [:]

    public init() {}

    public func register(_ tool: Tool) {
        tools[tool.name] = tool
    }

    public func descriptors() -> [ToolDescriptor] {
        tools.values
            .map(\.descriptor)
            .sorted { $0.name < $1.name }
    }

    public func dispatch(name: String, args: JSONValue) async -> ToolResult {
        guard let tool = tools[name] else {
            return .failure(.object(["error": .string("unknown tool: \(name)")]))
        }
        do {
            return .success(try await tool.invoke(args))
        } catch {
            return .failure(.object(["error": .string(String(describing: error))]))
        }
    }
}

public enum ToolResult: Sendable {
    case success(JSONValue)
    case failure(JSONValue)

    public var content: JSONValue {
        switch self {
        case .success(let v), .failure(let v): return v
        }
    }

    public var isError: Bool {
        if case .failure = self { return true }
        return false
    }
}

// MARK: - Helpers

enum ToolInputError: Error {
    case invalidDate(String)
    case invalidDecimal(String)
}

func parseDate(_ string: String) throws -> AcornDate {
    let parts = string.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3,
          let date = AcornDate(year: parts[0], month: parts[1], day: parts[2])
    else {
        throw ToolInputError.invalidDate(string)
    }
    return date
}

func parseDecimal(_ string: String) throws -> Decimal {
    guard let value = Decimal(string: string) else {
        throw ToolInputError.invalidDecimal(string)
    }
    return value
}
