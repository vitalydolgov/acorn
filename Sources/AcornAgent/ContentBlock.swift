import Foundation
import JSONSchema

public enum ContentBlock: Codable, Sendable {
    case text(String)
    case toolUse(id: String, name: String, input: JSONValue)
    case toolResult(toolUseID: String, content: JSONValue, isError: Bool)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case id, name, input
        case toolUseID = "tool_use_id"
        case content
        case isError = "is_error"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "tool_use":
            self = .toolUse(
                id: try container.decode(String.self, forKey: .id),
                name: try container.decode(String.self, forKey: .name),
                input: try container.decode(JSONValue.self, forKey: .input)
            )
        case "tool_result":
            self = .toolResult(
                toolUseID: try container.decode(String.self, forKey: .toolUseID),
                content: try container.decode(JSONValue.self, forKey: .content),
                isError: try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "unknown content block type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseID, let content, let isError):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseID, forKey: .toolUseID)
            try container.encode([ContentBlock.text(Self.serialize(content))], forKey: .content)
            try container.encode(isError, forKey: .isError)
        }
    }

    private static func serialize(_ value: JSONValue) -> String {
        if case let .string(s) = value { return s }
        guard let data = try? JSONEncoder().encode(value),
              let json = String(data: data, encoding: .utf8)
        else { return "null" }
        return json
    }

    public var asText: String? {
        if case let .text(t) = self { return t }
        return nil
    }

    public var asToolUse: (id: String, name: String, input: JSONValue)? {
        if case let .toolUse(id, name, input) = self { return (id, name, input) }
        return nil
    }
}
