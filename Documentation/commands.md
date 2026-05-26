# Commands

State-changing operations that a UI or the LLM agent drives, each running inside a single atomic unit of work. Listed with the domain intent each expresses, grouped by the aggregate it serves. See [queries.md](queries.md) for read-only operations.

## Accounts

| Operation | Description |
| --- | --- |
| `AddAccount` | Add an account with a name and optional notes. |
| `ChangeAccountName` | Rename an account. |
| `UpdateAccountMetadata` | Edit an account's notes. |
| `AdjustAccountBalance` | Adjust an account to a known balance by posting a correcting entry. |
| `CloseAccount` | Close an account, zeroing any remaining balance first. |
| `ReopenAccount` | Reopen a closed account. |
| `DeleteAccount` | Delete an account once it holds no entries. |

## Transactions

| Operation | Description |
| --- | --- |
| `RecordTransaction` | Record a transaction against an open account. |
| `ChangeTransactionAmount` | Change a transaction's amount. |
| `ChangeTransactionDate` | Change a transaction's date. |
| `ClearTransaction` | Clear a transaction. |
| `UnclearTransaction` | Unclear a transaction. |
| `ReconcileTransaction` | Reconcile a cleared transaction. |
| `DeleteTransaction` | Delete a transaction. |

## Transfers

A transfer moves money between two of your own accounts. It is not a standalone aggregate: it is recorded as two linked entries — an outflow from the source and a matching inflow into the destination — kept bound together so the balances always agree and a transfer is never left half-recorded.

| Operation | Description |
| --- | --- |
| `RecordTransfer` | Record a transfer between two distinct accounts for a positive amount. |
| `ChangeTransferAmount` | Change a transfer's amount, applied to both sides at once. |
| `ChangeTransferDate` | Change a transfer's date, applied to both sides at once. |
| `DeleteTransfer` | Delete a transfer, removing both sides together. |

Clearing, unclearing, and reconciling are done per side as it settles, reusing the transaction commands (`ClearTransaction`, `UnclearTransaction`, `ReconcileTransaction`).
