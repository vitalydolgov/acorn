---
name: build-and-test
description: Build the project and run the test suite
---

1. Run !`swift build`
2. Fix every reported error and warning, then build again — repeat until the build is clean.
3. Run !`swift test` and fix failures until the suite is green.

> Tests mirror the source layout; suites are named after the operation under test, covering domain invariants, use cases against the in-memory store, and the agent tool wrappers.
> Integration tests call the real Anthropic API and are gated off by default — run them only when asked, with !`ACORN_LLM_TESTS=1 swift test` and an `ANTHROPIC_API_KEY` set.
