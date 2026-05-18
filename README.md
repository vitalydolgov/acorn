# Acorn

A Swift library for zero-based budgeting, inspired by YNAB's mechanics. Scoped to the **domain** and **application** layers — no UI. Domain operations run through a **dual interface**: a human user (UI) and an LLM agent that invokes the same application use cases as tools.

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
- Anthropic API for the LLM agent

## Modules

- `AcornDomain` — entities, value objects, repository protocols, domain logic.
- `AcornApplication` — one type per use case, plus `UnitOfWork` for use cases that span aggregates.
- `AcornMacros` — Macros that remove boilerplate from the application layer.
- `AcornAgent` — exposes application use cases to an LLM as tools.
- `AcornInMemory` — in-memory persistence implementation. Shared test store, not a production adapter.

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
