# Acorn

A Swift library for zero-based budgeting, inspired by YNAB's mechanics, scoped to the domain and application layers (no UI) with a DDD shape and tests as the primary validation vehicle; domain operations run through a dual interface, driven both by a human user (UI) and by an LLM agent that invokes the same application use cases as tools. 

Read `README.md` for goals and tech stack; learn structure and layout from the code itself.

## Conventions

- Use cases run through the `@UnitOfWork` macro (`AcornMacros`), which injects `ctx` for repository access and atomic commit/rollback — there's no visible `ctx` declaration to grep for, so don't add one or bypass it with direct repo calls.
