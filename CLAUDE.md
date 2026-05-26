# Acorn

A Swift library for zero-based budgeting, inspired by YNAB's mechanics, scoped to the domain and application layers (no UI) with a DDD shape and tests as the primary validation vehicle; domain operations run through a dual interface, driven both by a human user (UI) and by an LLM agent that invokes the same application use cases as tools. 

Read `README.md` for goals and tech stack; learn structure and layout from the code itself.

## Conventions

- Use cases run through the `@UnitOfWork` macro (`AcornMacros`), which injects `ctx` for repository access and atomic commit/rollback — there's no visible `ctx` declaration to grep for, so don't add one or bypass it with direct repo calls.
- One type per use case, invoked via `callAsFunction`. State changes live in `Commands/<Aggregate>/`, read-only queries in `Queries/<Aggregate>/`, shared plumbing (`UnitOfWork`, `ApplicationError`) in `Shared/`.
- Name use cases by intent, not CRUD: `Record*`/`Add*` to create, `Change*` for single-field edits (`ChangeTransactionAmount`, `ChangeAccountName`), `Adjust*` for balance corrections, `UpdateAccountMetadata` for incidental fields, lifecycle verbs (`Clear`/`Unclear`/`Reconcile`/`Close`/`Reopen`/`Delete`); queries use `Get*` for one result and `List*` for a collection.
- Commands return the entity they create (or nothing for edits); queries return value DTOs (e.g. `GetBalance.Balances`).
- A transfer is two linked `Transaction` legs, not a separate aggregate. Edit amount/date or delete only through the `Transfer*` use cases (both legs move together); editing a leg through a `Transaction` use case is rejected. Clearing/unclearing/reconciling is done per leg through the regular transaction use cases.
