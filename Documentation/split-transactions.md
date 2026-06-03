# Design: Split transactions

A **split** is one transaction whose total is divided across several lines. In
YNAB terms it is the seam where a single purchase ("$100 at the store") is
broken into parts ("$60 groceries, $40 household") that will each carry their
own category. Acorn has no categories yet, so the immediate differentiator
between lines is amount alone — but the structure introduced here is precisely
the one a future per-line category/memo will attach to, and that is the main
reason to model it now rather than retrofit it later.

This document proposes the domain shape, the application and agent surface, and
the changes each layer needs. It does not change behaviour on its own; it is a
plan to be reviewed before implementation.

## Core idea: every transaction is a split of one or more lines

Rather than bolt a separate "split" entity onto regular transactions, a
`Transaction` **always owns a non-empty list of lines**. A regular transaction
is just a transaction with one line; a split is one with several. The lines are
**value objects inside the Transaction aggregate** — they have no identity or
lifecycle outside it, so they are not separate entities, not separate rows, and
not independently fetchable.

The transaction's `amount` becomes the **derived total** of its lines. This is
the keystone: because the total is always the sum of the lines, the existing
balance math — which already sums `tx.amount` — stays correct with no change,
and there is no second row holding the total to double-count.

```swift
public struct Transaction: Versioned, Sendable {
    public let id: UUID
    public var version: Int = 0
    public let accountID: UUID
    public private(set) var date: AcornDate
    public private(set) var status: TransactionStatus
    public let kind: TransactionKind
    public private(set) var lines: [TransactionLine]   // invariant: never empty
    public private(set) var isDeleted: Bool = false

    public var amount: Decimal { lines.reduce(0) { $0 + $1.amount } }
    public var isSplit: Bool { lines.count > 1 }
}

public struct TransactionLine: Sendable, Equatable, Codable {
    public let id: UUID        // local addressing within the transaction only
    public var amount: Decimal
    // future: categoryID, memo
}
```

### Why this shape

- **Math is uniform.** Everything is summed in terms of lines; a regular
  transaction is the degenerate one-line case. There is no `isBalanceAffecting`
  flag and no parent-vs-item branching anywhere.
- **The aggregate boundary is correct.** A line has no meaning apart from its
  transaction, so it lives *inside* the aggregate as a value object. An
  alternative parent/child design that modelled lines as separate `Transaction`
  entities was rejected for fragmenting the aggregate and for the row-doubling,
  status-syncing, and double-counting problems it dragged in.
- **One transaction stays one transaction.** Date and cleared/reconciled status
  are singular on the transaction; lines never carry their own, so they cannot
  drift.

## Domain layer (`AcornDomain`)

### `TransactionLine`

A new value object (above). `id` exists only to address a line within its
transaction (e.g. "change this line's category"); it is never persisted or
fetched as a top-level row.

### `Transaction`

- `amount` changes from a stored property to a computed total over `lines`.
  Existing readers of `.amount` keep working unchanged — it is still the total.
- `lines` is the stored decomposition, with the invariant that it is never
  empty.
- `isSplit` is `lines.count > 1`. **"Split" is not a `TransactionKind`** —
  `kind` stays `regular | adjustment | transfer`, describing the transaction's
  nature, which is orthogonal to how many lines it has.
- `rehydrate` takes `lines` instead of `amount` (the persistence mapper supplies
  them; see the SwiftData section for how legacy single-amount rows are read).

Factories:

```swift
// Single-line regular transaction — the common case.
package static func add(accountID:amount:date:cleared:) -> Transaction
// wraps the amount in a one-element lines array.

// Multi-line split: divide `amount` (the total) across `lineAmounts`.
package static func split(
    accountID: UUID,
    amount: Decimal,
    date: AcornDate,
    cleared: Bool,
    lineAmounts: [Decimal]
) throws -> Transaction
```

`split` enforces (throwing `DomainError.invalidArgument`):

- `lineAmounts.count >= 2` — a one-line split is just a regular transaction.
- every amount `!= 0`.
- the lines sum to `amount` — this is the total-anchored entry contract (below).

`amount` is the **stated total** the lines must balance against; it is *not*
stored — once validated it equals the derived `amount`, so persisting it
separately would only invite drift. Mixed signs are allowed (a purchase with a
refund line is real). `adjustment` and `transfer` factories stay single-line,
and a guard keeps multi-line restricted to `.regular` so transfers and
adjustments cannot be split.

Mutators:

- `update(amount:date:)` on a one-line transaction sets that line's amount and
  the date (unchanged behaviour for the common case). Calling it on a split is
  rejected — splits are edited by replacing their lines.
- `reviseSplit(amount:lineAmounts:date:)` replaces the line set and the date
  atomically, enforcing the same `>= 2`, non-zero, and sum-to-`amount` rules.
- `setDate(_:)` moves any transaction, split or not, without touching its lines.
- `delete` / `clear` / `unclear` / `reconcile` are unchanged — they act on the
  one transaction and need no awareness of lines.

### Entry workflow (total-anchored)

This mirrors YNAB: the user states the transaction amount, then divides it among
subtransactions, and the split cannot be saved until the lines balance to that
total. The library enforces only the committed, balanced state — `amount` is
validated against the lines at `recordSplit` / `changeSplit` and is never
stored. The in-progress **unassigned remainder** (amount minus the lines entered
so far) is transient entry state owned by the UI, not the domain.

### Balance

`BalanceCalculator` is **unchanged**. It already sums `tx.amount`, and
`tx.amount` is now the line total, so a split contributes its total to the
balance exactly once and respects the same cleared/uncleared status filtering.

## Application layer (`AcornApplication`)

### Repository protocol

**Unchanged.** Lines travel inside the `Transaction`, so there is no
`fetch(parentID:)`, no child lookup, and no new save path. A persistence adapter
must store and hydrate `lines` atomically with the transaction (a serialized
column or a child table loaded as part of the aggregate); the in-memory store
gets this for free since it holds the value.

### `TransactionCommands`

Splits are operations on the Transaction aggregate, so they live here rather
than in a separate command family (there is no second aggregate to coordinate):

- `recordSplit(accountID:amount:lineAmounts:date:cleared:) -> Transaction` —
  assert the account is postable, build via `Transaction.split`, save, return.
- `changeSplit(transactionID:amount:lineAmounts:date:cleared:)` — load the
  transaction, replace its lines, save. One aggregate, one version, atomic by
  default — no multi-row coordination, no cascade.
- `delete`, `clear`, `unclear`, `reconcile`, `changeDate` already operate on the
  whole transaction and work on splits as-is.
- `changeAmount` / `changeDetails` (the single-amount editors) reject a split
  ("transaction is split; use ChangeSplit"), mirroring how they already reject
  transfer legs.

Lines pass as `[Decimal]` for now. Once a line carries a category, this becomes
a `SplitLine` value (`amount` + `categoryID` + `memo`) parallel to
`TransactionDetails`; the amount-only array is the minimal shape until then.

### Queries (`TransactionQueries`)

- `get(transactionID:)` and `list(accountID:)` are **unchanged** — each returns
  whole transactions, now carrying their `lines`. No separate item query is
  needed because there are no item rows to fetch.

## Agent layer (`AcornAgent`)

`TransactionTools` gains split operations (no new tool family, matching the
command layer):

- `record_split` — `account_id`, `amount` (the total), `date`, `cleared`, and
  `lines` as a JSON array of `{ "amount": "..." }` objects that must sum to
  `amount` (`.array(items: .object(...))`).
- `change_split` — `transaction_id`, `amount`, `date`, `cleared`, `lines`.

Passing the total explicitly lets the domain reject an unbalanced split — useful
insurance against an LLM that miscounts the line amounts.

`TransactionDTO` gains the breakdown so the model can see and edit it:

```
is_split (bool), lines: [{ id, amount }]
```

`amount` stays in the DTO as the total. The existing `record_transaction` /
`change_transaction_*` / `delete_transaction` tools are untouched and operate on
the one-line common case.

## Cross-cutting

- **Atomicity** — a split is a single aggregate in a single row, so recording
  or editing it is one `save` in one `@UnitOfWork`; it can never be left
  half-written, and per-row `Versioned` optimistic locking applies as-is.
- **Postability** — the account is asserted postable before a split is written,
  as with plain transactions.
- **Persistence** — `amount` moves from stored to derived, so factories,
  mutators, and `rehydrate` reconstruct from `lines`. See the SwiftData section
  for the matching store change (pre-release, so a plain schema change, no
  migration).

## Persistence (SwiftData — `acorn-mobile`)

The mobile app's `Persistence` layer maps each domain aggregate to a flat
`@Model` record and translates in a mapper. Two of its conventions decide the
shape here:

- **Flat rows, no `@Relationship`.** A transfer is two separate
  `TransactionRecord` rows linked by a denormalized `transferID: UUID?` column —
  relationships are not used. That linking pattern is for *cross-aggregate*
  references (two transactions on two accounts).
- **Value types persist as Codable blobs; denormalize only what must be
  queried.** `AcornDate` and `TransactionKind` (an enum with associated values)
  are stored directly as properties. `ordinalDate: Int` and `transferID` exist
  solely because `#Predicate` / `SortDescriptor` cannot reach inside those
  blobs.

### Storing the lines: a `TransactionLineRecord` with a cascade relationship

Lines are *intra-aggregate* value objects — unlike transfer legs (which are two
separate aggregates on two accounts, rightly two rows linked by `transferID`).
The domain `Transaction` owns its `[TransactionLine]` regardless of storage, and
the mapper hides the storage shape behind it.

Lines persist as their own `@Model` joined to the transaction by a
`@Relationship(deleteRule: .cascade)`. This is the first relationship in the
store; it is the idiomatic SwiftData composition and keeps lines queryable in
SQL, which the budgeting layer will want once each line carries a category.

```swift
@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var version: Int
    var accountID: UUID
    var date: AcornDate
    var ordinalDate: Int
    var status: TransactionStatus
    var kind: TransactionKind
    var transferID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \TransactionLineRecord.transaction)
    var lines: [TransactionLineRecord] = []     // NEW
    var isDeleted: Bool
}

@Model
final class TransactionLineRecord {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var transaction: TransactionRecord?         // inverse
    // future: categoryID, memo
}
```

`TransactionLineRecord.self` joins the `Schema`. The stored `amount` column on
`TransactionRecord` is **dropped** — it is the derived total of `lines`, and
nothing queries or sorts on it (the predicates use `id`, `accountID`,
`transferID`, `ordinalDate`, `isDeleted`).

Mapping translates between the line records and the domain's `TransactionLine`
value objects, so the domain never sees the records:

```swift
static func toDomain(_ r: TransactionRecord) -> Transaction {
    let lines = r.lines.map { TransactionLine(id: $0.id, amount: $0.amount) }
    return Transaction.rehydrate(/* …, */ lines: lines)   // amount is derived
}
```

`toRecord` creates a `TransactionLineRecord` per line; `apply` (in-place update)
**reconciles** the set against `TransactionLine.id` — update records whose `id`
still exists, insert new ones, delete records whose `id` is gone (cascade covers
deleting the whole transaction, but an in-place revise must remove dropped lines
explicitly). The current revise API takes amounts only, so a revise replaces the
records wholesale, which the reconcile handles; id-stable surgical updates
become relevant once a line carries a category worth preserving across edits.

`Transaction.rehydrate` takes `lines` in place of `amount`.

### Clean schema, no migration

The project is pre-release with no data to preserve, so this is a plain schema
change rather than a migration: the `lines` relationship and
`TransactionLineRecord` are added, the `amount` column is removed, and the store
starts fresh.

### When lines need to be queried

Today balances are computed in-memory by `BalanceCalculator` over fetched
transactions, not in SQL, so a serialized `lines` blob queries fine. If a future
feature needs database-level aggregation across lines (e.g. a per-category
total), follow the store's own rule and denormalize then — hoist a queryable
column, or promote lines to a `TransactionLineRecord` table keyed by
`transactionID` (the `transferID` pattern) — rather than paying for it now.

## Out of scope (future extensions)

- **Categories / memos per line** — the reason lines are first-class; lands as
  fields on `TransactionLine` and `SplitLine` with no change to the shape.
- **A split line that is itself a transfer** — YNAB allows a split line to move
  money to another account. That points a value-object line at another
  aggregate and is the messy advanced case; deliberately excluded from the first
  cut.
