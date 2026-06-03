# Conventions

## Layering

- Every state change goes through application use cases over the `UnitOfWork` — never call repositories directly.
- The Domain layer holds no infrastructure types (`Date`, `URLSession`, etc.); pass such values in as domain abstractions.
- The Agent is a consumer of the Application layer, not a layer of its own — it adds no business logic, only wraps use cases as tools.
- Domain logic — filtering, aggregating, computing balances and policy checks — lives in the domain, not in commands, queries, or tools.

## Swift

- Swift 6, strict concurrency on. Domain types should be `Sendable` by construction (value types, no reference state).
- Default to `internal`. Use `package` for declarations that must cross module boundaries within this package but should not be visible outside it. Use `public` only for what a presentation or infrastructure layer depending on this package would consume.
- Doc comments are a single short line. No parameter or returns blocks. When the function can throw, add a `- Throws:` block describing the conditions — not the concrete error types.

## Safety

- Never use force unwrap (`!`) or force try (`try!`) — use `guard let … else { preconditionFailure(…) }` so the impossible case is explicit and loud rather than a silent crash.
- Never use `@unchecked Sendable` — if the compiler cannot verify `Sendable`, investigate whether the type truly is sendable and refactor to make that evident (e.g. immutable state, actor isolation) rather than suppressing the check.
