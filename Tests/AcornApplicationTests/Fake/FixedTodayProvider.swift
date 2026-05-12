import AcornDomain

struct FixedTodayProvider: TodayProvider {
    let date: AcornDate
    func today() -> AcornDate { date }
}
