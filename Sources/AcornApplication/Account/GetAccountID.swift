import Foundation
import AcornDomain

public struct GetAccountID: Sendable {
    public enum Result: Sendable {
        case found(UUID)
        case ambiguous([Account])
    }

    private let unitOfWork: any UnitOfWork

    public init(unitOfWork: any UnitOfWork) {
        self.unitOfWork = unitOfWork
    }

    @UnitOfWork
    public func callAsFunction(name: String) async throws -> Result {
        guard let normalized = AccountValidation.normalizedName(name) else {
            throw ApplicationError.invalidArgument("name must not be blank")
        }
        let needle = normalized.lowercased()
        let matches = try await ctx.accounts.all()
            .filter { !$0.isDeleted && $0.name.lowercased() == needle }
        switch matches.count {
        case 0:
            throw ApplicationError.notFound
        case 1:
            return .found(matches[0].id)
        default:
            return .ambiguous(matches.sorted { $0.name < $1.name })
        }
    }
}
