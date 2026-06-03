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

    @Test("real model dispatches list_accounts for an account question", .requiresLLM)
    func dispatchesListAccounts() async throws {
        let uow = InMemoryUnitOfWork()
        try await uow.accounts.save(try Account.make(name: "Checking", notes: ""))
        try await uow.accounts.save(try Account.make(name: "Savings", notes: ""))

        let runtime = makeRuntime(uow)
        await runtime.send("What accounts do I have?")

        #expect(toolNames(in: await runtime.messages).contains("list_accounts"))
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
        await runtime.send("What's the balance of my Checking account?")

        let messages = await runtime.messages
        let names = toolNames(in: messages)
        #expect(names.contains("get_account_id"))
        #expect(names.contains("calculate_balance"))
        if let idIdx = names.firstIndex(of: "get_account_id"),
           let balIdx = names.firstIndex(of: "calculate_balance") {
            #expect(idIdx < balIdx)
        }
        #expect(lastAssistantReply(in: messages).contains("250"))
    }

    @Test("real model renames an account without reading it first", .requiresLLM)
    func renamesAccount() async throws {
        let uow = InMemoryUnitOfWork()
        let checking = try Account.make(name: "Checking", notes: "primary spending")
        try await uow.accounts.save(checking)

        let runtime = makeRuntime(uow)
        await runtime.send("Rename my Checking account to Everyday.")

        let names = toolNames(in: await runtime.messages)
        #expect(names.contains("change_account_name"))
        #expect(!names.contains("get_account"))

        let stored = try await uow.accounts.fetch(id: checking.id)
        #expect(stored?.name == "Everyday")
        #expect(stored?.notes == "primary spending")
    }
}
