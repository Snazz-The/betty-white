import Foundation

/// One meaningful event from the Messages API server-sent event stream.
enum StreamEvent: Equatable {
    case textDelta(String)
    case stop
    case error(String)
}

/// Parses `data:` lines of the Messages API SSE stream. Event names are also carried
/// in each payload's `type` field, so `event:` lines can be ignored.
enum SSEParser {
    private struct Payload: Decodable {
        struct Delta: Decodable {
            let type: String?
            let text: String?
        }
        struct ErrorBody: Decodable {
            let message: String?
        }
        let type: String
        let delta: Delta?
        let error: ErrorBody?
    }

    static func parse(line: String) -> StreamEvent? {
        guard line.hasPrefix("data:") else { return nil }
        let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return nil }

        switch payload.type {
        case "content_block_delta":
            guard payload.delta?.type == "text_delta", let text = payload.delta?.text else { return nil }
            return .textDelta(text)
        case "message_stop":
            return .stop
        case "error":
            return .error(payload.error?.message ?? "Unknown API error")
        default:
            return nil
        }
    }
}
