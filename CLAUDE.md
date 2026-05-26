# Acorn

A Swift library for zero-based budgeting, inspired by YNAB's mechanics, scoped to the domain and application layers (no UI) with a DDD shape and tests as the primary validation vehicle; domain operations run through a dual interface, driven both by a human user (UI) and by an LLM agent that invokes the same application use cases as tools. 

Read `README.md` for goals and tech stack; learn structure and layout from the code itself.

## Conventions

- Every state-changing use case runs inside a single atomic unit of work that grants repository access and commits or rolls back as a whole; never bypass it with direct repository calls.
- Model each operation as its own type, invoked via `callAsFunction`. Keep state-changing commands separate from read-only queries, each grouped by the aggregate it serves (e.g. `Commands/`, `Queries/`), with shared plumbing kept apart.
- Name a use case for the domain intent it expresses, not a generic CRUD verb: a create reads as `Record…`/`Add…`, a single-field edit as `Change…`, a correction as `Adjust…`, an incidental/metadata edit as `Update…`, and a state transition as a lifecycle verb (`Clear`/`Close`/`Reopen`/…). Reads use `Get…` for one result and `List…` for a collection, while a value derived by computation over an aggregate's data reads as `Calculate…`.
- An invariant that spans more than one aggregate cannot be enforced by any single aggregate root: enforce it in the use case that coordinates the participants, inside one unit of work, and reject any operation that would change a participant in isolation. (Example: a transfer is not its own aggregate but two correlated transaction aggregates created, changed, and deleted together; editing one leg on its own is rejected.)

## Docs

Keep these in sync as you change the code:

- `Documentation/commands.md` and `Documentation/queries.md` — the catalogs of application operations grouped by aggregate (state-changing commands and read-only queries respectively). Update the matching doc whenever you add, rename, or remove an operation, or change what one does.
- `README.md` — update the module list and the capability coverage named in the introduction when the layout or surface area changes.
