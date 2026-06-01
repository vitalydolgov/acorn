# Acorn

Zero-based budgeting library (YNAB-inspired), covering domain and application layers only — no UI. Domain operations run through a **dual interface**: a human-driven UI and an LLM agent that calls the same application use cases as tools.

**Stack:** Swift 6.3

## Architecture

Domain-Driven Design across two layers, dependencies pointing inward:

- **Domain** — entities, repository protocols, domain logic. No infrastructure types (`Date`, `URLSession`, etc.).
- **Application** — commands and queries that orchestrate the domain. Defines the `UnitOfWork` protocol; never touches infrastructure directly.

`AcornAgent` is a consumer of the application layer, not a layer itself — it wraps use cases as LLM tools and owns the chat session. `AcornInMemory` provides test-only implementations of the repository and `UnitOfWork` protocols. `AcornMacros` is a compiler plugin with no runtime dependencies.

### What goes where — quick test

Before placing code, ask: *would this still make sense if the app were a CLI, a server endpoint, and a mobile application simultaneously?*

- "Yes" → Domain
- "Yes, but something has to drive it" → Application
- "Only relevant to AI interaction" → Agent
- "Only with this storage / only on this platform" → adapter, not in this package

## Key concepts

**Unit of work** — `@UnitOfWork` wraps a method body in `unitOfWork.perform { ctx in … }`, providing `ctx: RepositoryContext` for repository access. Every state change must go through it; never call repositories directly.

**Commands** — one struct per aggregate (or coordinating domain concept), grouping all state-changing operations and holding shared dependencies once. Each method runs inside a unit of work.

**Queries** — one struct per aggregate, grouping all read-only operations in the same shape as commands.

**Agent tools** — each operation is a private struct nested inside the relevant `*Tools` type, conforming to the `AgentTool` protocol. Each tool captures only the command or query dependency it needs.

## Development

Always run the build after every code change and fix all errors before reporting the task as done:

```sh
swift build
```

Tests mirror source layout; suites are named after the operation under test. Run with:

```sh
swift test                        # offline suite
ACORN_LLM_TESTS=1 swift test      # include live Anthropic API tests (paid)
```

### Conventions

- Swift 6, strict concurrency on. Domain types should be `Sendable` by construction (value types, no reference state).

- Default to `internal`. Use `package` for declarations that must cross module boundaries within this package but should not be visible outside it. Use `public` only for what a presentation or infrastructure layer depending on this package would consume.

## Documentation

`README.md` — update the module list and capability coverage when layout or surface area changes.
