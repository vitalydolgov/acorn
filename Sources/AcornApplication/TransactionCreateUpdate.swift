import Foundation
import AcornDomain

public struct TransactionCreateUpdate: Sendable {
    private let accountRepository: any AccountRepository
    private let transactionRepository: any TransactionRepository

    public init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
    }

    public func post(accountID: UUID, amount: Decimal, date: AcornDate) async throws -> Transaction {
        try await assertPostable(accountID)
        let transaction = Transaction.post(accountID: accountID, amount: amount, date: date)
        try await transactionRepository.save(transaction)
        return transaction
    }

    public func adjust(accountID: UUID, amount: Decimal, date: AcornDate) async throws -> Transaction {
        try await assertPostable(accountID)
        let transaction = try Transaction.adjust(accountID: accountID, amount: amount, date: date)
        try await transactionRepository.save(transaction)
        return transaction
    }

    public func transfer(
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) async throws -> (outflow: Transaction, inflow: Transaction) {
        try await assertPostable(fromAccountID)
        try await assertPostable(toAccountID)
        let pair = try Transaction.transfer(
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            amount: amount,
            date: date
        )
        try await transactionRepository.save(pair.outflow)
        try await transactionRepository.save(pair.inflow)
        return pair
    }

    public func update(transactionID: UUID, amount: Decimal, date: AcornDate) async throws {
        guard var transaction = try await transactionRepository.get(id: transactionID) else {
            throw ApplicationError.notFound
        }
        try transaction.update(amount: amount, date: date)
        try await transactionRepository.save(transaction)
    }

    private func assertPostable(_ accountID: UUID) async throws {
        guard let account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        try account.assertPostable()
    }
}
