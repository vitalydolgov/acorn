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
        try await postable(accountID)
        let transaction = Transaction.post(accountID: accountID, amount: amount, date: date)
        try await transactionRepository.save(transaction)
        return transaction
    }

    public func adjust(accountID: UUID, amount: Decimal, date: AcornDate) async throws -> Transaction {
        try await postable(accountID)
        guard let transaction = Transaction.adjust(
            accountID: accountID,
            amount: amount,
            date: date
        ) else {
            throw ApplicationError.invalidArgument("amount")
        }
        try await transactionRepository.save(transaction)
        return transaction
    }

    public func update(transactionID: UUID, amount: Decimal, date: AcornDate) async throws {
        guard var transaction = try await transactionRepository.get(id: transactionID) else {
            throw ApplicationError.notFound
        }
        guard !transaction.isDeleted else {
            throw ApplicationError.invalidState
        }
        transaction.update(amount: amount, date: date)
        try await transactionRepository.save(transaction)
    }

    private func postable(_ accountID: UUID) async throws {
        guard let account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        guard !account.isDeleted, !account.isClosed else {
            throw ApplicationError.invalidState
        }
    }
}
