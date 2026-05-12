public struct SystemTodayProvider: TodayProvider {
    public init() {}
    public func today() -> AcornDate { .today() }
}
