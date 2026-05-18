import Foundation
import JSONSchema

public protocol LLMClient: Sendable {
    func complete(_ request: ChatRequest) async throws -> ChatResponse
}

public struct ChatRequest: Encodable, Sendable {
    public let model: String
    public let maxTokens: Int
    public let system: [SystemBlock]?
    public let tools: [ToolDescriptor]
    public let messages: [Message]

    public init(
        model: String,
        maxTokens: Int,
        system: [SystemBlock]? = nil,
        tools: [ToolDescriptor] = [],
        messages: [Message]
    ) {
        self.model = model
        self.maxTokens = maxTokens
        self.system = system
        self.tools = tools
        self.messages = messages
    }

    enum CodingKeys: String, CodingKey {
        case model, system, tools, messages
        case maxTokens = "max_tokens"
    }
}

public struct SystemBlock: Codable, Sendable {
    public let type: String
    public let text: String
    public let cacheControl: CacheControl?

    public init(text: String, cacheControl: CacheControl? = nil) {
        self.type = "text"
        self.text = text
        self.cacheControl = cacheControl
    }

    enum CodingKeys: String, CodingKey {
        case type, text
        case cacheControl = "cache_control"
    }
}

public struct CacheControl: Codable, Sendable {
    public let type: String

    public init(type: String = "ephemeral") {
        self.type = type
    }

    public static let ephemeral = CacheControl(type: "ephemeral")
}

public struct ToolDescriptor: Encodable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: JSONSchema

    public init(name: String, description: String, inputSchema: JSONSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

public struct Message: Codable, Sendable {
    public let role: Role
    public let content: [ContentBlock]

    public init(role: Role, content: [ContentBlock]) {
        self.role = role
        self.content = content
    }
}

public enum Role: String, Codable, Sendable {
    case user
    case assistant
}

public struct ChatResponse: Decodable, Sendable {
    public let id: String
    public let role: Role
    public let content: [ContentBlock]
    public let stopReason: String?
    public let usage: Usage

    public init(
        id: String,
        role: Role,
        content: [ContentBlock],
        stopReason: String?,
        usage: Usage
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.stopReason = stopReason
        self.usage = usage
    }

    enum CodingKeys: String, CodingKey {
        case id, role, content, usage
        case stopReason = "stop_reason"
    }
}

public struct Usage: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int?
    public let cacheReadInputTokens: Int?

    public init(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationInputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

public enum LLMError: Error, Sendable, Equatable {
    case invalidResponse
    case apiError(status: Int, body: String?)
    case iterationLimit
}
