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
- Swift 6.3
- Swift Testing
- Anthropic API for the LLM agent

## Modules

- `AcornDomain` — entities, value objects, repository protocols, domain logic.
- `AcornApplication` — one type per use case, plus `UnitOfWork` for use cases that span aggregates.
- `AcornMacros` — Macros that remove boilerplate from the application layer.
- `AcornAgent` — exposes application use cases to an LLM as tools.
- `AcornInMemory` — in-memory persistence implementation. Shared test store, not a production adapter.

## Testing

Test targets mirror the modules and suites are organized by aggregate to match the source layout, covering domain invariants, use cases against the in-memory store, and the agent tool wrappers.

Integration tests run separately: they call the real Anthropic API, are gated off by default, and run only with `ACORN_LLM_TESTS=1` and an `ANTHROPIC_API_KEY` set.

```sh
swift test                       # offline suite
ACORN_LLM_TESTS=1 swift test     # include paid live tests
```

## Documentation

- [Commands](Documentation/commands.md) — the state-changing operations (accounts, transactions, transfers) grouped by aggregate, in domain terms.
- [Queries](Documentation/queries.md) — the read-only operations (balance calculations and account lookups) grouped by aggregate, in domain terms.

## Extending with UI

The application services expose intent-named operations that return plain value types and throw typed errors, so a UI layer can bind them directly to view models without reshaping the domain. Persistence swaps in by implementing the repository protocols against a real store, with the UI rendering balances via the existing calculators and reacting to repository changes after each mutation.
