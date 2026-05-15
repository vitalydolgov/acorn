import Foundation
import AcornDomain

public struct AddTransaction: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(accountID: UUID, amount: Decimal, date: AcornDate) async throws -> Transaction {
        guard let account = try await ctx.accounts.get(id: accountID) else {
            throw ApplicationError.notFound
        }
        try account.assertPostable()
        let transaction = Transaction.add(accountID: accountID, amount: amount, date: date)
        try await ctx.transactions.save(transaction)
        return transaction
    }
}
