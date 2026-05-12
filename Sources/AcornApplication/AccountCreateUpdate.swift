import Foundation
import AcornDomain

// TODO: two-repo writes are not transactional — a failure between the account
// and transaction saves leaves inconsistent state. Revisit with a unit-of-work.
public struct AccountCreateUpdate: Sendable {
    private let accountRepository: any AccountRepository
    private let transactionRepository: any TransactionRepository
    private let todayProvider: TodayProvider

    public init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository,
        todayProvider: TodayProvider
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
        self.todayProvider = todayProvider
    }

    public func open(
        name: String,
        notes: String = "",
        openingBalance: Decimal
    ) async throws -> Account {
        guard let account = Account.make(name: name, notes: notes) else {
            throw ApplicationError.invalidArgument
        }
        try await accountRepository.save(account)
        if let opening = Transaction.starting(
            accountID: account.id,
            amount: openingBalance,
            date: todayProvider.today()
        ) {
            try await transactionRepository.save(opening)
        }
        return account
    }

    public func update(accountID: UUID, name: String, notes: String) async throws {
        guard let account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        guard !account.isDeleted else {
            throw ApplicationError.invalidState
        }
        guard let updated = account.updated(name: name, notes: notes) else {
            throw ApplicationError.invalidArgument
        }
        try await accountRepository.save(updated)
    }
}
