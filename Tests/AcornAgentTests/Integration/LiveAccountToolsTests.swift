import Foundation
import Testing
import AcornDomain
import AcornApplication
import AcornInMemory
@testable import AcornAgent

@Suite("LiveAccountTools", .tags(.integration))
struct LiveAccountToolsTests {
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

    @Test("real model dispatches list_accounts for an account question", .requiresLLM)
    func dispatchesListAccounts() async throws {
        let uow = InMemoryUnitOfWork()
        try await uow.accounts.save(try Account.make(name: "Checking", notes: ""))
        try await uow.accounts.save(try Account.make(name: "Savings", notes: ""))

        let catalog = ToolCatalog()
        await catalog.register(.listAccounts(ListAccounts(unitOfWork: uow)))

        let session = try session(catalog: catalog)
        _ = try await session.send("What accounts do I have?")

        #expect(await toolNames(session).contains("list_accounts"))
    }

    @Test("real model chains get_account_id then get_balance", .requiresLLM)
    func chainsNameToBalance() async throws {
        let uow = InMemoryUnitOfWork()
        let checking = try Account.make(name: "Checking", notes: "")
        try await uow.accounts.save(checking)
        try await uow.transactions.save(
            Transaction.add(accountID: checking.id, amount: 250, date: .today())
        )

        let catalog = ToolCatalog()
        await catalog.register(.getAccountID(GetAccountID(unitOfWork: uow)))
        await catalog.register(.getBalance(GetBalance(unitOfWork: uow)))

        let session = try session(catalog: catalog)
        let reply = try await session.send("What's the balance of my Checking account?")

        let names = await toolNames(session)
        #expect(names.contains("get_account_id"))
        #expect(names.contains("get_balance"))
        if let idIdx = names.firstIndex(of: "get_account_id"),
           let balIdx = names.firstIndex(of: "get_balance") {
            #expect(idIdx < balIdx)
        }
        #expect(reply.contains("250"))
    }

    @Test("real model renames an account without reading it first", .requiresLLM)
    func renamesAccount() async throws {
        let uow = InMemoryUnitOfWork()
        let checking = try Account.make(name: "Checking", notes: "primary spending")
        try await uow.accounts.save(checking)

        let catalog = ToolCatalog()
        await catalog.register(.getAccountID(GetAccountID(unitOfWork: uow)))
        await catalog.register(.changeAccountName(ChangeAccountName(unitOfWork: uow)))

        let session = try session(catalog: catalog)
        _ = try await session.send("Rename my Checking account to Everyday.")

        let names = await toolNames(session)
        #expect(names.contains("change_account_name"))
        #expect(!names.contains("get_account"))

        let stored = try await uow.accounts.fetch(id: checking.id)
        #expect(stored?.name == "Everyday")
        #expect(stored?.notes == "primary spending")
    }

}
