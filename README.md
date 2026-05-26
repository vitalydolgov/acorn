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

## Use cases

The application layer is one type per use case, split into state-changing **commands** and read-only **queries**, each grouped by aggregate:

```
Sources/AcornApplication/
  Commands/{Account,Transaction,Transfer}/
  Queries/Account/
  Shared/                       # UnitOfWork, ApplicationError
```

Each use case is a struct invoked via `callAsFunction`, so call sites read like a function call; commands run under the `@UnitOfWork` macro for atomic commit/rollback. Commands return the entity they create (or nothing for edits); queries return plain value DTOs (e.g. `GetBalance.Balances`).

Names state intent rather than CRUD:

- **Create** — `RecordTransaction`, `RecordTransfer`, `AddAccount`.
- **Edit one field** — `Change…` (`ChangeTransactionAmount`, `ChangeTransferDate`, `ChangeAccountName`).
- `AdjustAccountBalance` posts a balance-correcting transaction; `UpdateAccountMetadata` edits incidental fields such as notes.
- **Lifecycle** — `Clear`/`Unclear`/`Reconcile`/`Delete` a transaction; `Close`/`Reopen`/`Delete` an account.
- **Queries** — `Get…` for a single result, `List…` for collections.

### Transfers as linked transactions

A transfer is not a separate aggregate. `RecordTransfer` creates two mirrored `Transaction` legs — an outflow on the source account and an inflow on the destination — linked by a shared transfer id (`TransactionKind.transfer`). The `Transfer…` use cases edit or delete both legs together; editing a leg through a `Transaction` use case is rejected. This keeps the two sides consistent without a dedicated aggregate.

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
