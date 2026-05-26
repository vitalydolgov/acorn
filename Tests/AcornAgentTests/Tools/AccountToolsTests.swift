import Foundation
import Testing
import AcornDomain
import AcornApplication
import AcornInMemory
@testable import AcornAgent

@Suite("AccountTools")
struct AccountToolsTests {
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

    @Test("get_balance reports cleared, uncleared, and working balances")
    func getBalance() async throws {
        let uow = makeUoW()
        let checking = try Account.make(name: "Checking", notes: "")
        try await uow.accounts.save(checking)
        var clearedDeposit = Transaction.add(accountID: checking.id, amount: 250, date: .today())
        try clearedDeposit.clear()
        try await uow.transactions.save(clearedDeposit)
        try await uow.transactions.save(
            Transaction.add(accountID: checking.id, amount: -40, date: .today())
        )

        let catalog = ToolCatalog()
        await catalog.register(.getBalance(GetBalance(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "get_balance",
            args: .object(["account_id": .string(checking.id.uuidString)])
        )

        #expect(outcome.isError == false)
        #expect(outcome.content == .object([
            "cleared_balance": .string("250"),
            "uncleared_balance": .string("-40"),
            "working_balance": .string("210")
        ]))
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

    @Test("add_account creates the account and returns its descriptor")
    func addAccount() async throws {
        let uow = makeUoW()
        let catalog = ToolCatalog()
        await catalog.register(.addAccount(AddAccount(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "add_account",
            args: .object(["name": .string("Checking"), "notes": .string("primary")])
        )

        #expect(outcome.isError == false)
        #expect(outcome.content.objectValue?["name"]?.stringValue == "Checking")
        #expect(outcome.content.objectValue?["is_closed"]?.boolValue == false)
        let id = try #require(outcome.content.objectValue?["id"]?.stringValue)
        let uuid = try #require(UUID(uuidString: id))
        let stored = try await uow.accounts.fetch(id: uuid)
        #expect(stored?.name == "Checking")
    }

    @Test("add_account fails on a blank name")
    func addAccountBlankName() async throws {
        let uow = makeUoW()
        let catalog = ToolCatalog()
        await catalog.register(.addAccount(AddAccount(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "add_account",
            args: .object(["name": .string("   ")])
        )

        #expect(outcome.isError == true)
    }

    @Test("close_account closes the account")
    func closeAccount() async throws {
        let uow = makeUoW()
        let account = try Account.make(name: "Checking", notes: "")
        try await uow.accounts.save(account)

        let catalog = ToolCatalog()
        await catalog.register(
            .closeAccount(CloseAccount(unitOfWork: uow, todayProvider: SystemTodayProvider()))
        )

        let outcome = await catalog.dispatch(
            name: "close_account",
            args: .object(["account_id": .string(account.id.uuidString)])
        )

        #expect(outcome.isError == false)
        #expect(outcome.content == .object(["ok": .bool(true)]))
        let stored = try await uow.accounts.fetch(id: account.id)
        #expect(stored?.isClosed == true)
    }

    @Test("reopen_account reopens a closed account")
    func reopenAccount() async throws {
        let uow = makeUoW()
        let account = try await AddAccount(unitOfWork: uow)(name: "Checking")
        try await CloseAccount(unitOfWork: uow, todayProvider: SystemTodayProvider())(
            accountID: account.id
        )

        let catalog = ToolCatalog()
        await catalog.register(.reopenAccount(ReopenAccount(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "reopen_account",
            args: .object(["account_id": .string(account.id.uuidString)])
        )

        #expect(outcome.isError == false)
        let stored = try await uow.accounts.fetch(id: account.id)
        #expect(stored?.isClosed == false)
    }

    @Test("change_account_name renames the account")
    func changeAccountName() async throws {
        let uow = makeUoW()
        let account = try await AddAccount(unitOfWork: uow)(name: "Old", notes: "keep me")

        let catalog = ToolCatalog()
        await catalog.register(.changeAccountName(ChangeAccountName(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "change_account_name",
            args: .object([
                "account_id": .string(account.id.uuidString),
                "name": .string("New")
            ])
        )

        #expect(outcome.isError == false)
        let stored = try await uow.accounts.fetch(id: account.id)
        #expect(stored?.name == "New")
        #expect(stored?.notes == "keep me")
    }

    @Test("update_account_metadata updates the notes")
    func updateAccountMetadata() async throws {
        let uow = makeUoW()
        let account = try await AddAccount(unitOfWork: uow)(name: "Salary", notes: "old")

        let catalog = ToolCatalog()
        await catalog.register(.updateAccountMetadata(UpdateAccountMetadata(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "update_account_metadata",
            args: .object([
                "account_id": .string(account.id.uuidString),
                "notes": .string("rule: salary deposits only")
            ])
        )

        #expect(outcome.isError == false)
        let stored = try await uow.accounts.fetch(id: account.id)
        #expect(stored?.name == "Salary")
        #expect(stored?.notes == "rule: salary deposits only")
    }

    @Test("delete_account removes an account with no activity")
    func deleteAccount() async throws {
        let uow = makeUoW()
        let account = try await AddAccount(unitOfWork: uow)(name: "Checking")

        let catalog = ToolCatalog()
        await catalog.register(.deleteAccount(DeleteAccount(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "delete_account",
            args: .object(["account_id": .string(account.id.uuidString)])
        )

        #expect(outcome.isError == false)
        let stored = try await uow.accounts.fetch(id: account.id)
        #expect(stored?.isDeleted == true)
    }

    @Test("delete_account surfaces a failure when the account has activity")
    func deleteAccountWithActivityFails() async throws {
        let uow = makeUoW()
        let account = try await AddAccount(unitOfWork: uow)(name: "Checking")
        try await uow.transactions.save(
            Transaction.add(accountID: account.id, amount: 10, date: .today())
        )

        let catalog = ToolCatalog()
        await catalog.register(.deleteAccount(DeleteAccount(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "delete_account",
            args: .object(["account_id": .string(account.id.uuidString)])
        )

        #expect(outcome.isError == true)
        let stored = try await uow.accounts.fetch(id: account.id)
        #expect(stored?.isDeleted == false)
    }

    @Test("list_accounts includes account notes")
    func listAccountsIncludesNotes() async throws {
        let uow = makeUoW()
        try await uow.accounts.save(
            try Account.make(name: "Checking", notes: "salary only")
        )

        let catalog = ToolCatalog()
        await catalog.register(.listAccounts(ListAccounts(unitOfWork: uow)))

        let outcome = await catalog.dispatch(name: "list_accounts", args: .object([:]))

        #expect(outcome.isError == false)
        let notes = outcome.content.arrayValue?
            .compactMap { $0.objectValue?["notes"]?.stringValue }
        #expect(notes == ["salary only"])
    }

    @Test("get_account returns full info including notes")
    func getAccount() async throws {
        let uow = makeUoW()
        let account = try Account.make(name: "Checking", notes: "salary only; no transfers out")
        try await uow.accounts.save(account)

        let catalog = ToolCatalog()
        await catalog.register(.getAccount(GetAccount(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "get_account",
            args: .object(["account_id": .string(account.id.uuidString)])
        )

        #expect(outcome.isError == false)
        #expect(outcome.content.objectValue?["name"]?.stringValue == "Checking")
        #expect(outcome.content.objectValue?["notes"]?.stringValue == "salary only; no transfers out")
        #expect(outcome.content.objectValue?["is_closed"]?.boolValue == false)
        #expect(outcome.content.objectValue?["id"]?.stringValue == account.id.uuidString)
    }

    @Test("get_account surfaces a missing account as a failure")
    func getAccountNotFound() async throws {
        let uow = makeUoW()
        let catalog = ToolCatalog()
        await catalog.register(.getAccount(GetAccount(unitOfWork: uow)))

        let outcome = await catalog.dispatch(
            name: "get_account",
            args: .object(["account_id": .string(UUID().uuidString)])
        )

        #expect(outcome.isError == true)
        #expect(outcome.content.objectValue?["error"] != nil)
    }

    @Test("dispatching an unregistered tool is a failure")
    func unknownTool() async throws {
        let catalog = ToolCatalog()
        let outcome = await catalog.dispatch(name: "does_not_exist", args: .object([:]))

        #expect(outcome.isError == true)
        #expect(outcome.content.objectValue?["error"] != nil)
    }
}
