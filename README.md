# Acorn

A Swift library for zero-based budgeting, inspired by YNAB's mechanics. Scoped to the **domain** and **application** layers — no UI.

## Goals

- Model personal-finance budgeting with a clean DDD shape.
- State can be updated by several actors at once — a human user and an agent.
- Atomic domain operations: either fully succeed or leave state untouched.
- Undo stack over domain operations.
- Use tests as the primary validation vehicle for behavior and invariants.

## Tech stack

- swift-tools 6.2
- iOS 17 / macOS 14
- Swift 6 (strict concurrency)

## Modules

- `AcornDomain` — entities, value objects, repository protocols, domain logic.
- `AcornApplication` — one type per use case, plus `UnitOfWork` for use cases that span aggregates.

## Status

- [x] Basic account and transaction
- [x] Account lifecycle: close, reopen, delete
- [x] Open account
- [x] Update account with validation
- [x] Cleared and uncleared balance
- [x] Transaction lifecycle: clear, unclear, reconcile, delete
- [x] Deposit, withdraw and adjust transactions
- [x] Update transaction with validation
- [x] Transfers between accounts
- [x] Transactional operations (Unit of Work for multi-aggregate use cases, with rollback)
- [x] Aggregate versioning
- [ ] Categories
- [ ] Plans (zero-based monthly allocation)
- [ ] Payees
- [ ] Reconciliation flow
- [ ] Undo stack
- [ ] Domain events
- [ ] Pagination
- [ ] ...

Persistence is intentionally out of scope: the library ships repository and `UnitOfWork` protocols, and the consuming app provides the adapter (Core Data, GRDB, SQLite, CloudKit, …) that fits its storage choice.

## Extending with UI

The application services expose intent-named operations that return plain value types and throw typed errors, so a UI layer can bind them directly to view models without reshaping the domain. Persistence swaps in by implementing the repository protocols against a real store, with the UI rendering balances via the existing calculators and reacting to repository changes after each mutation.
