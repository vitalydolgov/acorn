import Foundation
import AcornDomain

public struct ListAccounts: Sendable {
    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction() async throws -> [Account] {
        let all = try await ctx.accounts.all()
        return all
            .filter { !$0.isDeleted }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}
