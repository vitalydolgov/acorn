# Acorn

Zero-based budgeting library (YNAB-inspired) in Swift, covering domain and application layers only — no UI. Domain operations run through a **dual interface**: a human-driven UI and an LLM agent that calls the same application use cases as tools.

**Stack:** Swift 6.3

## Modules

| Module | Role |
| --- | --- |
| `AcornDomain` | Entities, repository protocols, calculations, domain errors |
| `AcornApplication` | Command/query structs, cross-aggregate coordination, `UnitOfWork` protocol |
| `AcornMacros` | `@UnitOfWork` body macro — compiler plugin that wraps methods in a unit-of-work scope |
| `AcornAgent` | Wraps application use cases as LLM tools; owns chat session and tool dispatch |
| `AcornInMemory` | In-memory repositories and `UnitOfWork`; used exclusively in tests |

## Layout

```
AcornApplication/
  Commands/   one struct per aggregate
  Queries/    one struct per aggregate
  Shared/     UnitOfWork · shared value types
AcornAgent/
  Tools/      one struct per aggregate
```

## Key concepts

**Unit of work** — `@UnitOfWork` wraps a method body in `unitOfWork.perform { ctx in … }`, providing `ctx: RepositoryContext` for repository access. Every state change must go through it; never call repositories directly.

**Commands** — one struct per aggregate (or coordinating domain concept), grouping all state-changing operations and holding shared dependencies once. Each method runs inside a unit of work.

**Queries** — one struct per aggregate, grouping all read-only operations in the same shape as commands.

**Agent tools** — each operation is a private struct nested inside the relevant `*Tools` type, conforming to the `AgentTool` protocol. Each tool captures only the command or query dependency it needs.

## Conventions

- Swift 6, strict concurrency on. Domain types should be `Sendable` by construction (value types, no reference state).
- Default to `internal`. Use `package` for declarations that must cross module boundaries within this package but should not be visible outside it. Use `public` only for what a presentation or infrastructure layer depending on this package would consume.

## Tests

Mirror source layout; suites are named after the operation under test.

```sh
swift test                        # offline suite
ACORN_LLM_TESTS=1 swift test      # include live Anthropic API tests (paid)
```

## Documentation

`README.md` — update the module list and capability coverage when layout or surface area changes.
