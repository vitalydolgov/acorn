# Acorn

A Swift library for zero-based budgeting, inspired by YNAB's mechanics, scoped to the domain and application layers (no UI) with a DDD shape and tests as the primary validation vehicle; domain operations run through a dual interface, driven both by a human user (UI) and by an LLM agent that invokes the same application use cases as tools. 

Read `README.md` for goals and tech stack; learn structure and layout from the code itself.

## Conventions

- Every state-changing use case runs inside a single atomic unit of work that grants repository access and commits or rolls back as a whole; never bypass it with direct repository calls. (Here that's the `@UnitOfWork` macro, which injects `ctx` — there's no visible `ctx` to grep for, so don't add one.)
- Model each operation as its own type, invoked via `callAsFunction`. Keep state-changing commands separate from read-only queries, each grouped by the aggregate it serves (e.g. `Commands/<Aggregate>/`, `Queries/<Aggregate>/`), with shared plumbing kept apart.
- Name a use case for the domain intent it expresses, not a generic CRUD verb: a create reads as `Record…`/`Add…`, a single-field edit as `Change…`, a correction as `Adjust…`, an incidental/metadata edit as `Update…`, and a state transition as a lifecycle verb (`Clear`/`Close`/`Reopen`/…). Reads use `Get…` for one result and `List…` for a collection.
- A command returns the entity it creates (or nothing for an edit); a query returns a plain value DTO, never a mutable domain object.
- An invariant that spans more than one aggregate cannot be enforced by any single aggregate root: enforce it in the use case that coordinates the participants, inside one unit of work, and reject any operation that would change a participant in isolation. (Example: a transfer is not its own aggregate but two correlated transaction aggregates created, changed, and deleted together; editing one leg on its own is rejected.)
