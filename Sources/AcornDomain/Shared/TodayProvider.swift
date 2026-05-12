public protocol TodayProvider: Sendable {
    func today() -> AcornDate
}
