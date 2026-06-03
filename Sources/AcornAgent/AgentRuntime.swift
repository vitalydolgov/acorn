import Foundation
import AcornDomain
import AcornApplication

@Observable
@MainActor
public final class AgentRuntime {
    public static let defaultModel = "claude-haiku-4-5"
    public static let defaultMaxTokens = 4096
    public static let defaultSystemInstructions = """
        You are an assistant for the zero-based budgeting app. Respond concisely. Prefer actions over explanations.

        Guardrails:
        - Never expose internal identifiers in responses; refer to accounts and transactions by their user-visible names and dates only.
        - Never use markdown tables; use bullet lists or plain prose instead.
        """

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
        model: String = AgentRuntime.defaultModel,
        maxTokens: Int = AgentRuntime.defaultMaxTokens,
        systemInstructions: String = AgentRuntime.defaultSystemInstructions,
        maxIterations: Int = 10,
        context: @escaping (AgentDependencies) async throws -> String,
        dependencies: AgentDependencies
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
        self.context = { try await context(dependencies) }

        Task {
            let tools = AccountTools(unitOfWork: dependencies.unitOfWork, todayProvider: dependencies.todayProvider).all
                + TransactionTools(unitOfWork: dependencies.unitOfWork).all
                + TransferTools(unitOfWork: dependencies.unitOfWork).all
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

extension AgentRuntime {
    public nonisolated static func defaultContext(_ dependencies: AgentDependencies) async throws -> String {
        let today = dependencies.todayProvider.today()
        let accounts = try await AccountQueries(unitOfWork: dependencies.unitOfWork).list()
        var lines = ["Today: \(today.year)-\(today.month)-\(today.day)"]
        if !accounts.isEmpty {
            lines.append("Accounts:")
            lines += accounts.map { "- \($0.name)" }
        }
        return lines.joined(separator: "\n")
    }
}
