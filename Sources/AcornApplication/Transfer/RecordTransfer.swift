import Foundation
import AcornDomain

public struct RecordTransfer: Sendable {
    private let accountRepository: any AccountRepository
    private let transferRepository: any TransferRepository

    public init(
        accountRepository: any AccountRepository,
        transferRepository: any TransferRepository
    ) {
        self.accountRepository = accountRepository
        self.transferRepository = transferRepository
    }

    public func callAsFunction(
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) async throws -> Transfer {
        try await assertPostable(fromAccountID)
        try await assertPostable(toAccountID)
        let transfer = try Transfer.create(
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            amount: amount,
            date: date
        )
        try await transferRepository.save(transfer)
        return transfer
    }

    private func assertPostable(_ accountID: UUID) async throws {
        guard let account = try await accountRepository.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        try account.assertPostable()
    }
}
