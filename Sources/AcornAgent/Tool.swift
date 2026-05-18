import Foundation
import JSONSchema

public struct Tool: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema
    public let invoke: @Sendable (JSONValue) async throws -> JSONValue

    public init(
        name: String,
        description: String,
        inputSchema: JSONSchema,
        invoke: @Sendable @escaping (JSONValue) async throws -> JSONValue
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.invoke = invoke
    }

    public var descriptor: ToolDescriptor {
        ToolDescriptor(name: name, description: description, inputSchema: inputSchema)
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

    public func dispatch(name: String, args: JSONValue) async -> ToolOutcome {
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

public enum ToolOutcome: Sendable {
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
