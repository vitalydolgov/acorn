import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct AnthropicClient: LLMClient {
    private let apiKeyProvider: @Sendable () async throws -> String
    private let endpoint: URL
    private let anthropicVersion: String
    private let session: URLSession

    public init(
        apiKeyProvider: @Sendable @escaping () async throws -> String,
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        anthropicVersion: String = "2023-06-01",
        session: URLSession = .shared
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.endpoint = endpoint
        self.anthropicVersion = anthropicVersion
        self.session = session
    }

    public func complete(_ request: ChatRequest) async throws -> ChatResponse {
        var http = URLRequest(url: endpoint)
        http.httpMethod = "POST"
        http.setValue("application/json", forHTTPHeaderField: "Content-Type")
        http.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        http.setValue(try await apiKeyProvider(), forHTTPHeaderField: "x-api-key")
        http.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: http)
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw LLMError.invalidResponse
        }
        guard (200..<300).contains(status) else {
            throw LLMError.apiError(status: status, body: String(data: data, encoding: .utf8))
        }
        return try JSONDecoder().decode(ChatResponse.self, from: data)
    }
}
