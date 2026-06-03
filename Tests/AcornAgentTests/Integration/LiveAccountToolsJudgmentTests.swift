import Foundation
import Testing
import AcornDomain
import AcornApplication
import AcornInMemory
@testable import AcornAgent

/// Live tests that assert on the model's *judgment* rather than mechanics.
/// A failure here signals prompt/tool-description quality, not a code bug.
@Suite("LiveAccountToolsJudgment", .tags(.integration))
@MainActor
struct LiveAccountToolsJudgmentTests {
    private func makeRuntime(_ uow: InMemoryUnitOfWork) -> AgentRuntime {
        let todayProvider = SystemTodayProvider()
        return AgentRuntime(
            model: "claude-haiku-4-5",
            maxTokens: 512,
            systemInstructions: """
                You are Acorn's chat agent. Use the provided tools to answer \
                questions about the user's accounts. Resolve account names to \
                ids with get_account_id before calling tools that need an id. \
                If get_account_id reports ambiguity, ask the user to clarify.
                """,
            context: AgentRuntime.defaultContext,
            dependencies: AgentDependencies(unitOfWork: uow, todayProvider: todayProvider)
        )
    }

    private func toolNames(_ runtime: AgentRuntime) -> [String] {
        runtime.messages
            .flatMap(\.content)
            .compactMap(\.asToolUse)
            .map(\.name)
    }

    @Test("real model asks to disambiguate instead of guessing", .requiresLLM)
    func handlesAmbiguity() async throws {
        let uow = InMemoryUnitOfWork()
        try await uow.accounts.save(try Account.make(name: "Savings", notes: "joint"))
        try await uow.accounts.save(try Account.make(name: "Savings", notes: "personal"))

        let runtime = makeRuntime(uow)
        await runtime.send("What's the balance of my Savings account?")

        let names = toolNames(runtime)
        #expect(names.contains("get_account_id"))
        // Ambiguity must not be resolved into a balance lookup.
        #expect(!names.contains("calculate_balance"))
    }

    @Test("real model answers without tools when none are needed", .requiresLLM)
    func noToolWhenUnnecessary() async throws {
        let runtime = makeRuntime(InMemoryUnitOfWork())
        await runtime.send("In one word, say hello.")

        #expect(toolNames(runtime).isEmpty)
        let reply = runtime.messages
            .last(where: { $0.role == .assistant })
            .map { $0.content.compactMap(\.asText).joined() } ?? ""
        #expect(!reply.isEmpty)
    }
}
