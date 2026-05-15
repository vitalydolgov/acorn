import Foundation
import AcornDomain

public struct AddTransaction: Sendable {
    private let accountRepository: any AccountRepository
    private let transactionRepository: any TransactionRepository

    public init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
    }

    public func callAsFunction(accountID: UUID, amount: Decimal, date: AcornDate) async throws -> Transaction {
        guard let account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        try account.assertPostable()
        let transaction = Transaction.add(accountID: accountID, amount: amount, date: date)
        try await transactionRepository.save(transaction)
        return transaction
    }
}
