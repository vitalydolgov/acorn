# Acorn

A library for zero-based budgeting, inspired by YNAB's mechanics. Scoped to the **domain** and **application** layers only — no UI. Domain operations run through a **dual interface**: a human user (UI) and an LLM agent that invokes the same application use cases as tools.

**Stack:** Swift 6

## Features

- **Atomic operations** — every change runs in a unit of work and either fully commits or rolls back.
- **Built-in LLM agent** — a ready-made agent runtime (chat session, tool catalog, Anthropic client) that drives the same use cases through natural language.

## Architecture

Domain-Driven Design across two layers, dependencies pointing inward:

- **Domain** — entities, value objects, repository protocols, domain logic. No infrastructure types (`Date`, `URLSession`, etc.).
- **Application** — commands and queries that orchestrate the domain. Defines the `UnitOfWork` protocol; never touches infrastructure directly.

`AcornAgent` is a consumer of the application layer, not a layer itself — it wraps use cases as LLM tools and owns the chat session. `AcornInMemory` provides test-only implementations of the repository and `UnitOfWork` protocols. `AcornMacros` is a compiler plugin with no runtime dependencies.

### Modules

- `AcornDomain` — entities, value objects, repository protocols, domain logic.
- `AcornApplication` — commands and queries over the domain, plus the `UnitOfWork` protocol for use cases that span aggregates.
- `AcornMacros` — macros that remove boilerplate from the application layer.
- `AcornAgent` — exposes application use cases to an LLM as tools.
- `AcornInMemory` — in-memory persistence implementation. Shared test store, not a production adapter.

## Key concepts

**Unit of work** — `@UnitOfWork` wraps a method body in `unitOfWork.perform { ctx in … }`, providing `ctx: RepositoryContext` for repository access. Every state change must go through it; never call repositories directly.

**Commands** — one struct per aggregate (or coordinating domain concept), grouping all state-changing operations and holding shared dependencies once. Each method runs inside a unit of work.

**Queries** — one struct per aggregate, grouping all read-only operations in the same shape as commands.

**Agent tools** — each operation is a private struct nested inside the relevant `*Tools` type, conforming to the `AgentTool` protocol. Each tool captures only the command or query dependency it needs.

## Documentation

- [`conventions.md`](Documentation/conventions.md) — coding conventions; consult before writing or reviewing any code.
- [`repository.md`](Documentation/repository.md) — repository rules (commits, pull requests).
