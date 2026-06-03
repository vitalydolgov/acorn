import Foundation

/// One allocation within a transaction. A regular transaction has a single line; a split has
/// several whose amounts sum to the transaction's total. `id` addresses a line within its
/// transaction only — lines have no identity or lifecycle of their own.
public struct TransactionLine: Codable, Equatable, Sendable {
    public let id: UUID
    public var amount: Decimal

    public init(id: UUID = UUID(), amount: Decimal) {
        self.id = id
        self.amount = amount
    }
}
