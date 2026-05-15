import Foundation
import AcornDomain

public struct DeleteAccount: Sendable {
    private let accountRepository: any AccountRepository
    private let transactionRepository: any TransactionRepository
    private let transferRepository: any TransferRepository

    public init(
        accountRepository: any AccountRepository,
        transactionRepository: any TransactionRepository,
        transferRepository: any TransferRepository
    ) {
        self.accountRepository = accountRepository
        self.transactionRepository = transactionRepository
        self.transferRepository = transferRepository
    }

    public func callAsFunction(accountID: UUID) async throws {
        guard var account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        let transactions = try await transactionRepository.forAccount(accountID)
        let transfers = try await transferRepository.forAccount(accountID)
        let hasLiveTransactions = transactions.contains { !$0.isDeleted }
        let hasLiveTransfers = transfers.contains { !$0.isDeleted }
        guard !hasLiveTransactions && !hasLiveTransfers else {
            throw ApplicationError.invalidState
        }
        try account.delete()
        try await accountRepository.save(account)
    }
}
