import Foundation
import JSONSchema

public actor ChatSession {
    private let client: any LLMClient
    private let catalog: ToolCatalog
    private let model: String
    private let maxTokens: Int
    private let systemPrompt: String
    private let maxIterations: Int

    private var history: [Message] = []

    public init(
        client: any LLMClient,
        catalog: ToolCatalog,
        model: String = "claude-haiku-4-5",
        maxTokens: Int = 4096,
        systemPrompt: String,
        maxIterations: Int = 10
    ) {
        self.client = client
        self.catalog = catalog
        self.model = model
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.maxIterations = maxIterations
    }

    public var transcript: [Message] { history }

    public func send(_ userText: String) async throws -> String {
        history.append(Message(role: .user, content: [.text(userText)]))

        for _ in 0..<maxIterations {
            let descriptors = await catalog.descriptors()
            let request = ChatRequest(
                model: model,
                maxTokens: maxTokens,
                system: [SystemBlock(text: systemPrompt, cacheControl: .ephemeral)],
                tools: descriptors,
                messages: history
            )

            let response = try await client.complete(request)
            history.append(Message(role: .assistant, content: response.content))

            let toolUses = response.content.compactMap(\.asToolUse)
            if toolUses.isEmpty {
                return response.content
                    .compactMap(\.asText)
                    .joined(separator: "\n")
            }

            var results: [ContentBlock] = []
            for use in toolUses {
                let outcome = await catalog.dispatch(name: use.name, args: use.input)
                results.append(.toolResult(
                    toolUseID: use.id,
                    content: outcome.content,
                    isError: outcome.isError
                ))
            }
            history.append(Message(role: .user, content: results))
        }
        throw LLMError.iterationLimit
    }
}
