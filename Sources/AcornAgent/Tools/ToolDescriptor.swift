import Foundation
import JSONSchema

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
