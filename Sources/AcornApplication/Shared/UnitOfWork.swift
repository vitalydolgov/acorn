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

/// Wraps the annotated function's body in `try await unitOfWork.perform { ctx in … }`,
/// so the body runs inside a single unit-of-work scope with `ctx: RepositoryContext` in scope.
///
/// The enclosing type must expose a property named `unitOfWork` of type `any UnitOfWork`.
/// Inside the body, access repositories via `ctx.accounts`, `ctx.transactions`, etc.
@attached(body)
public macro UnitOfWork() = #externalMacro(module: "AcornMacros", type: "UnitOfWorkMacro")
