# Acorn

A Swift library for zero-based budgeting, inspired by YNAB's mechanics. Scoped to the **domain** and **application** layers — no UI. Domain operations run through a **dual interface**: a human user (UI) and an LLM agent that invokes the same application use cases as tools.

## Goals

- Model personal-finance budgeting with a clean DDD shape.
- State can be updated by several actors at once — a human user and an agent.
- Atomic domain operations: either fully succeed or leave state untouched.
- Undo stack over domain operations.
- Use tests as the primary validation vehicle for behavior and invariants.

## Tech stack

- iOS 17 / macOS 14
- Swift 6.2 toolchain
- Swift Testing
- Anthropic API for the LLM agent

## Modules

- `AcornDomain` — entities, value objects, repository protocols, domain logic.
- `AcornApplication` — one type per use case, plus `UnitOfWork` for use cases that span aggregates.
- `AcornMacros` — Macros that remove boilerplate from the application layer.
- `AcornAgent` — exposes application use cases to an LLM as tools.
- `AcornInMemory` — in-memory persistence implementation. Shared test store, not a production adapter.

## Application layer

The application layer exposes the budgeting features as use cases that a UI or the LLM agent drives. What's covered today, in domain terms:

**Accounts**

- Add an account with a name and optional notes; rename it or edit its notes (`AddAccount`, `ChangeAccountName`, `UpdateAccountMetadata`).
- Adjust an account to a known balance by posting a correcting entry (`AdjustAccountBalance`).
- Close an account — zeroing any remaining balance first — and reopen it later (`CloseAccount`, `ReopenAccount`).
- Delete an account once it holds no entries (`DeleteAccount`).

**Transactions**

- Record a transaction against an open account (`RecordTransaction`).
- Change a transaction's amount or date (`ChangeTransactionAmount`, `ChangeTransactionDate`).
- Clear and unclear a transaction; reconcile a cleared one (`ClearTransaction`, `UnclearTransaction`, `ReconcileTransaction`).
- Delete a transaction (`DeleteTransaction`).

**Transfers**

A transfer moves money between two of your own accounts. It is not a standalone concept: it is recorded as two linked entries — an outflow from the source and a matching inflow into the destination — kept bound together so the balances always agree and a transfer is never left half-recorded.

- Record a transfer between two distinct accounts for a positive amount (`RecordTransfer`).
- Change a transfer's amount or date, applied to both sides at once (`ChangeTransferAmount`, `ChangeTransferDate`).
- Delete a transfer, removing both sides together (`DeleteTransfer`).
- Clear, unclear, and reconcile each side on its own as it settles (`ClearTransaction`, `UnclearTransaction`, `ReconcileTransaction`).

**Balances & lookup**

- Read an account's cleared, uncleared, and working balances (`GetBalance`).
- Fetch an account by id, resolve one by name (flagging ambiguous matches), and list all accounts (`GetAccount`, `GetAccountID`, `ListAccounts`).

## Testing

Test targets mirror the modules and suites are organized by aggregate to match the source layout, covering domain invariants, use cases against the in-memory store, and the agent tool wrappers.

Integration tests run separately: they call the real Anthropic API, are gated off by default, and run only with `ACORN_LLM_TESTS=1` and an `ANTHROPIC_API_KEY` set.

```sh
swift test                       # offline suite
ACORN_LLM_TESTS=1 swift test     # include paid live tests
```

## Status

- [x] Accounts & transactions — full lifecycle, validation, balances
- [x] Transfers & transactional integrity — Unit of Work, rollback, versioning
- [x] LLM agent interface — application use cases exposed as tools
- [ ] Budgeting core — categories, plans, payees
- [ ] Reconciliation & undo
- [ ] Scale & observability — domain events, pagination

Persistence is intentionally out of scope: the library ships repository and `UnitOfWork` protocols, and the consuming app provides the adapter (Core Data, GRDB, SQLite, CloudKit, …) that fits its storage choice.

## Extending with UI

The application services expose intent-named operations that return plain value types and throw typed errors, so a UI layer can bind them directly to view models without reshaping the domain. Persistence swaps in by implementing the repository protocols against a real store, with the UI rendering balances via the existing calculators and reacting to repository changes after each mutation.
