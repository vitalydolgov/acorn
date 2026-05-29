import Foundation
import Testing
import AcornDomain
import AcornApplication
import AcornInMemory
@testable import AcornAgent

@Suite("LiveAccountTools", .tags(.integration))
@MainActor
struct LiveAccountToolsTests {
    private func makeRuntime(_ uow: InMemoryUnitOfWork) -> AgentRuntime {
        AgentRuntime(
            unitOfWork: uow,
            todayProvider: SystemTodayProvider(),
            model: "claude-haiku-4-5",
            maxTokens: 512,
            systemPrompt: """
                You are Acorn's chat agent. Use the provided tools to answer \
                questions about the user's accounts. Resolve account names to \
                ids with get_account_id before calling tools that need an id. \
                If get_account_id reports ambiguity, ask the user to clarify.
                """
        )
    }

    private func send(_ text: String, runtime: AgentRuntime) async throws -> String {
        await runtime.send(text)
        if let error = runtime.sendError { throw error }
        return runtime.messages
            .last(where: { $0.role == .assistant })
            .map { $0.content.compactMap(\.asText).joined() } ?? ""
    }

    private func toolNames(_ runtime: AgentRuntime) -> [String] {
        runtime.messages
            .flatMap(\.content)
            .compactMap(\.asToolUse)
            .map(\.name)
    }

    @Test("real model dispatches list_accounts for an account question", .requiresLLM)
    func dispatchesListAccounts() async throws {
        let uow = InMemoryUnitOfWork()
        try await uow.accounts.save(try Account.make(name: "Checking", notes: ""))
        try await uow.accounts.save(try Account.make(name: "Savings", notes: ""))

        let runtime = makeRuntime(uow)
        _ = try await send("What accounts do I have?", runtime: runtime)

        #expect(toolNames(runtime).contains("list_accounts"))
    }

    @Test("real model chains get_account_id then calculate_balance", .requiresLLM)
    func chainsNameToBalance() async throws {
        let uow = InMemoryUnitOfWork()
        let checking = try Account.make(name: "Checking", notes: "")
        try await uow.accounts.save(checking)
        try await uow.transactions.save(
            Transaction.add(accountID: checking.id, amount: 250, date: .today())
        )

        let runtime = makeRuntime(uow)
        let reply = try await send("What's the balance of my Checking account?", runtime: runtime)

        let names = toolNames(runtime)
        #expect(names.contains("get_account_id"))
        #expect(names.contains("calculate_balance"))
        if let idIdx = names.firstIndex(of: "get_account_id"),
           let balIdx = names.firstIndex(of: "calculate_balance") {
            #expect(idIdx < balIdx)
        }
        #expect(reply.contains("250"))
    }

    @Test("real model renames an account without reading it first", .requiresLLM)
    func renamesAccount() async throws {
        let uow = InMemoryUnitOfWork()
        let checking = try Account.make(name: "Checking", notes: "primary spending")
        try await uow.accounts.save(checking)

        let runtime = makeRuntime(uow)
        _ = try await send("Rename my Checking account to Everyday.", runtime: runtime)

        let names = toolNames(runtime)
        #expect(names.contains("change_account_name"))
        #expect(!names.contains("get_account"))

        let stored = try await uow.accounts.fetch(id: checking.id)
        #expect(stored?.name == "Everyday")
        #expect(stored?.notes == "primary spending")
    }
}
