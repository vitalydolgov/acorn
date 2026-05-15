import Foundation
import AcornDomain

public protocol RepositoryContext: Sendable {
    var accounts: any AccountRepository { get }
    var transactions: any TransactionRepository { get }
    var transfers: any TransferRepository { get }
}

public protocol UnitOfWork: Sendable {
    func perform<T: Sendable>(
        _ body: @Sendable (any RepositoryContext) async throws -> T
    ) async throws -> T
}
