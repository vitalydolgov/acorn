public protocol AgentContext: Sendable {
    func get() async throws -> String
}
