import AcornDomain
import AcornApplication

func sessionContext(unitOfWork: any UnitOfWork, todayProvider: any TodayProvider) -> () async throws -> String {
    {
        let today = todayProvider.today()
        let accounts = try await AccountQueries(unitOfWork: unitOfWork).list()
        var lines = ["Today: \(today.year)-\(today.month)-\(today.day)"]
        if !accounts.isEmpty {
            lines.append("Accounts:")
            lines += accounts.map { "- \($0.name)" }
        }
        return lines.joined(separator: "\n")
    }
}
