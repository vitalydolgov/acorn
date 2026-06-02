import AcornDomain
import AcornApplication
import AcornAgent

struct SessionContextProvider: AgentContext {
    private let queries: AccountQueries
    private let todayProvider: any TodayProvider

    init(unitOfWork: any UnitOfWork, todayProvider: any TodayProvider) {
        self.queries = AccountQueries(unitOfWork: unitOfWork)
        self.todayProvider = todayProvider
    }

    func get() async throws -> String {
        let today = todayProvider.today()
        let accounts = try await queries.list()
        var lines = ["Today: \(today.year)-\(today.month)-\(today.day)"]
        if !accounts.isEmpty {
            lines.append("Accounts:")
            lines += accounts.map { "- \($0.name)" }
        }
        return lines.joined(separator: "\n")
    }
}
