import Foundation
import Testing
import AcornDomain
import AcornApplication
import AcornInMemory
@testable import AcornAgent

@Suite("ToolCatalog")
struct ToolCatalogTests {
    private func makeUoW() -> InMemoryUnitOfWork { InMemoryUnitOfWork() }

    @Test("list_accounts returns the registered accounts")
    func listAccounts() async throws {
        let uow = makeUoW()
        try await uow.accounts.save(try Account.make(name: "Checking", notes: ""))
        try await uow.accounts.save(try Account.make(name: "Savings", notes: ""))

        let catalog = ToolCatalog()
        await catalog.register(.listAccounts(ListAccounts(unitOfWork: uow)))

        let outcome = await catalog.dispatch(name: "list_accounts", args: .object([:]))

        #expect(outcome.isError == false)
        let names = outcome.content.arrayValue?
            .compactMap { $0.objectValue?["name"]?.stringValue }
            .sorted()
        #expect(names == ["Checking", "Savings"])
    }

    @Test("get_account_id resolves a unique name to its id")
    func getAccountIDFound() async throws {
        let uow = makeUoW()
        let checking = try Account.make(name: "Checking", notes: "")
        try await uow.accounts.save(checking)

        let catalog = ToolCatalog()
        await catalog.register(.getAccountID(GetAccountID(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "get_account_id",
            args: .object(["name": .string("Checking")])
        )

        #expect(outcome.isError == false)
        #expect(outcome.content == .object(["id": .string(checking.id.uuidString)]))
    }

    @Test("get_account_id reports ambiguity when names collide")
    func getAccountIDAmbiguous() async throws {
        let uow = makeUoW()
        try await uow.accounts.save(try Account.make(name: "Shared", notes: ""))
        try await uow.accounts.save(try Account.make(name: "Shared", notes: ""))

        let catalog = ToolCatalog()
        await catalog.register(.getAccountID(GetAccountID(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "get_account_id",
            args: .object(["name": .string("Shared")])
        )

        #expect(outcome.isError == false)
        let candidates = outcome.content.objectValue?["ambiguous"]?.arrayValue
        #expect(candidates?.count == 2)
    }

    @Test("get_account_id surfaces a no-match as a recoverable failure")
    func getAccountIDNotFound() async throws {
        let uow = makeUoW()
        let catalog = ToolCatalog()
        await catalog.register(.getAccountID(GetAccountID(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "get_account_id",
            args: .object(["name": .string("Nope")])
        )

        #expect(outcome.isError == true)
        #expect(outcome.content.objectValue?["error"] != nil)
    }

    @Test("get_balance sums transactions for the account")
    func getBalance() async throws {
        let uow = makeUoW()
        let checking = try Account.make(name: "Checking", notes: "")
        try await uow.accounts.save(checking)
        try await uow.transactions.save(
            Transaction.add(accountID: checking.id, amount: 250, date: .today())
        )

        let catalog = ToolCatalog()
        await catalog.register(.getBalance(GetBalance(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "get_balance",
            args: .object(["account_id": .string(checking.id.uuidString)])
        )

        #expect(outcome.isError == false)
        #expect(outcome.content == .object(["balance": .string("250")]))
    }

    @Test("get_balance fails when account_id is missing")
    func getBalanceMissingArg() async throws {
        let uow = makeUoW()
        let catalog = ToolCatalog()
        await catalog.register(.getBalance(GetBalance(unitOfWork: uow)))

        let outcome = await catalog.dispatch(name: "get_balance", args: .object([:]))

        #expect(outcome.isError == true)
    }

    @Test("get_balance fails when account_id is not a UUID")
    func getBalanceInvalidUUID() async throws {
        let uow = makeUoW()
        let catalog = ToolCatalog()
        await catalog.register(.getBalance(GetBalance(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "get_balance",
            args: .object(["account_id": .string("not-a-uuid")])
        )

        #expect(outcome.isError == true)
    }

    @Test("dispatching an unregistered tool is a failure")
    func unknownTool() async throws {
        let catalog = ToolCatalog()
        let outcome = await catalog.dispatch(name: "does_not_exist", args: .object([:]))

        #expect(outcome.isError == true)
        #expect(outcome.content.objectValue?["error"] != nil)
    }
}
