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
    private let context: () async throws -> String
    private let catalog: AgentToolCatalog
    private let model: String
    private let maxTokens: Int
    private let maxIterations: Int
    private let systemInstructions: String
    private var sessionContext: String?

    public init(
        model: String,
        maxTokens: Int,
        systemInstructions: String,
        maxIterations: Int = 10,
        context: @escaping () async throws -> String,
        unitOfWork: any UnitOfWork,
        todayProvider: any TodayProvider
    ) {
        let catalog = AgentToolCatalog()
        self.catalog = catalog
        self.client = AnthropicClient(apiKeyProvider: {
            Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String ?? ""
        })
        self.model = model
        self.maxTokens = maxTokens
        self.maxIterations = maxIterations
        self.systemInstructions = systemInstructions
        self.context = context

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

    public func resetSession() {
        sessionContext = nil
        messages = []
    }

    private func performSend(_ userText: String) async throws {
        if sessionContext == nil {
            sessionContext = try? await context()
        }
        messages.append(ChatMessage(role: .user, content: [.text(userText)]))
        print("[user] \(userText)")

        var system = [SystemBlock(text: systemInstructions, cacheControl: .ephemeral)]
        if let ctx = sessionContext, !ctx.isEmpty {
            system.append(SystemBlock(text: ctx, cacheControl: .ephemeral))
        }

        for _ in 0..<maxIterations {
            let request = ChatRequest(
                model: model,
                maxTokens: maxTokens,
                system: system,
                tools: await catalog.tools(),
                messages: messages
            )

            let response = try await client.complete(request)
            messages.append(ChatMessage(role: .assistant, content: response.content))
            let text = response.content.compactMap(\.asText).joined(separator: "\n")
            if !text.isEmpty { print("[assistant] \(text)") }

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
