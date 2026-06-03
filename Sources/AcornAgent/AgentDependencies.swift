import AcornDomain
import AcornApplication

public struct AgentDependencies: Sendable {
    public let unitOfWork: any UnitOfWork
    public let todayProvider: any TodayProvider

    public init(unitOfWork: any UnitOfWork, todayProvider: any TodayProvider) {
        self.unitOfWork = unitOfWork
        self.todayProvider = todayProvider
    }
}
