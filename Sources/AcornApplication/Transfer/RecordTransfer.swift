import Foundation
import AcornDomain

public struct RecordTransfer: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(
        fromAccountID: UUID,
        toAccountID: UUID,
        amount: Decimal,
        date: AcornDate
    ) async throws -> Transfer {
        for accountID in [fromAccountID, toAccountID] {
            guard let account = try await ctx.accounts.get(id: accountID) else {
                throw ApplicationError.notFound(accountID)
            }
            try account.assertPostable()
        }
        let transfer = try Transfer.create(
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            amount: amount,
            date: date
        )
        try await ctx.transfers.save(transfer)
        return transfer
    }
}
