import Foundation
import Testing
import AcornDomain
import AcornApplication
import AcornInMemory
@testable import AcornAgent

/// Live tests that assert on the model's *judgment* rather than mechanics.
/// A failure here signals prompt/tool-description quality, not a code bug.
@Suite("LiveAccountToolsJudgment", .tags(.integration))
struct LiveAccountToolsJudgmentTests {
    private func session(catalog: ToolCatalog) throws -> ChatSession {
        let key = try #require(
            ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
            "ANTHROPIC_API_KEY must be set"
        )
        return ChatSession(
            client: AnthropicClient(apiKeyProvider: { key }),
            catalog: catalog,
            maxTokens: 512,
            systemPrompt: """
                You are Acorn's chat agent. Use the provided tools to answer \
                questions about the user's accounts. Resolve account names to \
                ids with get_account_id before calling tools that need an id. \
                If get_account_id reports ambiguity, ask the user to clarify.
                """
        )
    }

    private func toolNames(_ session: ChatSession) async -> [String] {
        await session.transcript
            .flatMap(\.content)
            .compactMap(\.asToolUse)
            .map(\.name)
    }

    @Test("real model asks to disambiguate instead of guessing", .requiresLLM)
    func handlesAmbiguity() async throws {
        let uow = InMemoryUnitOfWork()
        try await uow.accounts.save(try Account.make(name: "Savings", notes: "joint"))
        try await uow.accounts.save(try Account.make(name: "Savings", notes: "personal"))

        let catalog = ToolCatalog()
        await catalog.register(.getAccountID(GetAccountID(unitOfWork: uow)))
        await catalog.register(.calculateBalance(CalculateBalance(unitOfWork: uow)))

        let session = try session(catalog: catalog)
        _ = try await session.send("What's the balance of my Savings account?")

        let names = await toolNames(session)
        #expect(names.contains("get_account_id"))
        // Ambiguity must not be resolved into a balance lookup.
        #expect(!names.contains("calculate_balance"))
    }

    @Test("real model answers without tools when none are needed", .requiresLLM)
    func noToolWhenUnnecessary() async throws {
        let catalog = ToolCatalog()
        await catalog.register(.listAccounts(ListAccounts(unitOfWork: InMemoryUnitOfWork())))

        let session = try session(catalog: catalog)
        let reply = try await session.send("In one word, say hello.")

        #expect(await toolNames(session).isEmpty)
        #expect(!reply.isEmpty)
    }
}
