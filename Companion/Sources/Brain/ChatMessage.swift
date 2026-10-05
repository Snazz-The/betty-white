import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
}

/// Where a user message came from. Voice messages get shorter, more conversational replies.
enum MessageOrigin {
    case typed
    case voice
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var text: String
    var origin: MessageOrigin = .typed
}
