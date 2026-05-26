# Queries

Read-only operations that return data and change nothing, including values derived by calculation. Listed with the domain intent each expresses, grouped by the aggregate it serves. See [commands.md](commands.md) for state-changing operations.

## Accounts

| Operation | Description |
| --- | --- |
| `CalculateBalance` | Calculate an account's cleared, uncleared, and working balances. |
| `GetAccount` | Fetch an account by id. |
| `GetAccountID` | Resolve an account by name, flagging ambiguous matches. |
| `ListAccounts` | List all accounts. |
