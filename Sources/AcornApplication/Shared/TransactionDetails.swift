import Foundation
import AcornDomain

/// Editable fields of an entry, from the perspective of the account in context.
/// `amount` is signed (positive inflow, negative outflow). A nil `counterpartAccountID`
/// denotes a regular transaction; a non-nil value denotes a transfer. `cleared` only ever
/// affects the context account's leg.
public struct TransactionDetails: Sendable {
    public let amount: Decimal
    public let date: AcornDate
    public let cleared: Bool
    public let counterpartAccountID: UUID?

    public init(amount: Decimal, date: AcornDate, cleared: Bool, counterpartAccountID: UUID?) {
        self.amount = amount
        self.date = date
        self.cleared = cleared
        self.counterpartAccountID = counterpartAccountID
    }
}

extension TransactionDetails {
    var magnitude: Decimal { abs(amount) }

    /// Resolves transfer endpoints relative to the context account from the sign of
    /// `amount`: an outflow makes the context account the source, an inflow the destination.
    func transferEndpoints(contextAccountID: UUID, counterpartID: UUID) -> (from: UUID, to: UUID) {
        amount < 0
            ? (from: contextAccountID, to: counterpartID)
            : (from: counterpartID, to: contextAccountID)
    }
}
