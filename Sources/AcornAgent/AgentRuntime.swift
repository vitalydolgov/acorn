import Foundation
import AcornDomain
import AcornApplication

@Observable
@MainActor
public final class AgentRuntime {
    public private(set) var messages: [ChatMessage] = []
    public private(set) var isSending = false
    public var sendError: Error?

    private let client: any LLMClient
    private let catalog: ToolCatalog
    private let model: String
    private let maxTokens: Int
    private let systemPrompt: String
    private let maxIterations: Int

    public init(
        unitOfWork: any UnitOfWork,
        todayProvider: any TodayProvider,
        model: String = "claude-haiku-4-5",
        maxTokens: Int = 4096,
        systemPrompt: String = "You are an assistant for the zero-based budgeting app. Respond concisely. Prefer actions over explanations.",
        maxIterations: Int = 10
    ) {
        let catalog = ToolCatalog()
        self.catalog = catalog
        self.client = AnthropicClient(apiKeyProvider: {
            Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String ?? ""
        })
        self.model = model
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.maxIterations = maxIterations

        Task {
            let tools = AccountTools(unitOfWork: unitOfWork, todayProvider: todayProvider).all
                + TransactionTools(unitOfWork: unitOfWork).all
                + TransferTools(unitOfWork: unitOfWork).all
            for tool in tools {
                await catalog.register(tool)
            }
        }
    }

    public func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await performSend(trimmed)
        } catch {
            sendError = error
        }
    }

    public func reset() {
        messages = []
    }

    private func performSend(_ userText: String) async throws {
        messages.append(ChatMessage(role: .user, content: [.text(userText)]))

        for _ in 0..<maxIterations {
            let descriptors = await catalog.descriptors()
            let request = ChatRequest(
                model: model,
                maxTokens: maxTokens,
                system: [SystemBlock(text: systemPrompt, cacheControl: .ephemeral)],
                tools: descriptors,
                messages: messages
            )

            let response = try await client.complete(request)
            messages.append(ChatMessage(role: .assistant, content: response.content))

            let toolUses = response.content.compactMap(\.asToolUse)
            if toolUses.isEmpty { return }

            var results: [ContentBlock] = []
            for use in toolUses {
                let outcome = await catalog.dispatch(name: use.name, args: use.input)
                results.append(.toolResult(
                    toolUseID: use.id,
                    content: outcome.content,
                    isError: outcome.isError
                ))
            }
            messages.append(ChatMessage(role: .user, content: results))
        }
        throw LLMError.iterationLimit
    }
}
