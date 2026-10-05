import Foundation

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case http(status: Int, message: String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key yet. Add one in Settings."
        case .http(401, _):
            return "The API key was rejected. Check it in Settings."
        case .http(429, _):
            return "Rate limited. Try again in a moment."
        case .http(let status, let message):
            return "API error \(status): \(message)"
        case .api(let message):
            return message
        }
    }

    /// Pulls `error.message` out of a JSON error body, falling back to the raw body.
    static func message(fromBody body: String) -> String {
        struct Body: Decodable {
            struct Inner: Decodable { let message: String }
            let error: Inner
        }
        if let data = body.data(using: .utf8), let parsed = try? JSONDecoder().decode(Body.self, from: data) {
            return parsed.error.message
        }
        return body.isEmpty ? "No details" : body
    }
}

/// Minimal streaming client for the Anthropic Messages API.
struct AnthropicClient {
    struct Message: Encodable, Equatable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
        let stream: Bool
    }

    let apiKey: String
    var session: URLSession = .shared

    /// Streams reply text chunks. Cancelling the consuming task cancels the request.
    func streamReply(system: String, messages: [Message], maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try makeRequest(system: system, messages: messages, maxTokens: maxTokens)
                    let (bytes, response) = try await session.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var body = ""
                        for try await line in bytes.lines { body += line }
                        throw AnthropicError.http(status: http.statusCode, message: AnthropicError.message(fromBody: body))
                    }

                    for try await line in bytes.lines {
                        switch SSEParser.parse(line: line) {
                        case .textDelta(let text): continuation.yield(text)
                        case .stop: continuation.finish(); return
                        case .error(let message): throw AnthropicError.api(message)
                        case nil: continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func makeRequest(system: String, messages: [Message], maxTokens: Int) throws -> URLRequest {
        var request = URLRequest(url: Config.apiURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Config.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            RequestBody(model: Config.model, max_tokens: maxTokens, system: system, messages: messages, stream: true)
        )
        return request
    }
}
