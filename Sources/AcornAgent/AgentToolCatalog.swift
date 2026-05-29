import JSONSchema

enum AgentToolResult: Sendable {
    case success(JSONValue)
    case failure(JSONValue)

    var content: JSONValue {
        switch self {
        case .success(let v), .failure(let v): return v
        }
    }

    var isError: Bool {
        if case .failure = self { return true }
        return false
    }
}

actor AgentToolCatalog {
    private var registry: [String: any AgentTool] = [:]

    func register(_ tool: some AgentTool) {
        registry[tool.name] = tool
    }

    func tools() -> [any AgentTool] {
        registry.values.sorted { $0.name < $1.name }
    }

    func dispatch(name: String, args: JSONValue) async -> AgentToolResult {
        guard let tool = registry[name] else {
            return .failure(.object(["error": .string("unknown tool: \(name)")]))
        }
        do {
            return .success(try await tool.invoke(args))
        } catch {
            return .failure(.object(["error": .string(String(describing: error))]))
        }
    }
}
