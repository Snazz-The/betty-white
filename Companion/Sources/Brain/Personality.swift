import Foundation

/// Loads the system prompt from the bundled Personality.md.
enum Personality {
    static let fallback = "You are a warm, concise desktop companion. Speak in short sentences."

    /// Appended to the system prompt when the user spoke rather than typed.
    static let voiceAddendum = """

    The user is speaking to you out loud and your reply will be read aloud. \
    Answer in one to three short, conversational sentences. \
    No markdown, lists, code, emoji, or URLs.
    """

    static func load(bundle: Bundle = .main) -> String {
        guard let url = bundle.url(forResource: "Personality", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return fallback }
        return text
    }

    static func systemPrompt(base: String, origin: MessageOrigin) -> String {
        origin == .voice ? base + voiceAddendum : base
    }
}
