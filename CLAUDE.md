# Acorn

A Swift library for zero-based budgeting, inspired by YNAB's mechanics. Scoped to the domain and application layers (no UI). DDD shape, undo stack, tests as the primary validation vehicle.

Dual interface: domain operations are driven both by a human user (UI) and by an LLM agent that invokes the same application use cases as tools.

## Tech stack

- swift-tools 6.2
- iOS 17
- Swift 6 (strict concurrency)
