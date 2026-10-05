import Foundation
import Observation

/// Owns the conversation and the companion's state. The menu bar chat, the desktop pet,
/// and the voice layer all observe this one object.
@MainActor
@Observable
final class CompanionBrain {
    private(set) var messages: [ChatMessage] = []
    private(set) var state: CompanionState = .idle
    var lastError: String?

    @ObservationIgnored private var replyTask: Task<Void, Never>?
    @ObservationIgnored private let personality: String
    @ObservationIgnored private let apiKeyProvider: @MainActor () -> String?

    init(
        personality: String = Personality.load(),
        apiKeyProvider: @escaping @MainActor () -> String? = { ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] }
    ) {
        self.personality = personality
        self.apiKeyProvider = apiKeyProvider
    }

    var isBusy: Bool { state == .thinking || state == .talking }

    func send(_ text: String, origin: MessageOrigin = .typed) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            lastError = AnthropicError.missingAPIKey.errorDescription
            return
        }

        lastError = nil
        messages.append(ChatMessage(role: .user, text: trimmed, origin: origin))
        let history = apiHistory()
        let reply = ChatMessage(role: .assistant, text: "", origin: origin)
        messages.append(reply)
        state = .thinking

        let client = AnthropicClient(apiKey: apiKey)
        let system = Personality.systemPrompt(base: personality, origin: origin)
        let maxTokens = origin == .voice ? Config.voiceMaxTokens : Config.typedMaxTokens

        replyTask = Task { [weak self] in
            do {
                for try await chunk in client.streamReply(system: system, messages: history, maxTokens: maxTokens) {
                    self?.append(chunk, to: reply.id)
                }
                self?.finishReply(reply.id, error: nil)
            } catch {
                self?.finishReply(reply.id, error: error)
            }
        }
    }

    /// Stops any in-flight reply and forgets the conversation.
    func clear() {
        replyTask?.cancel()
        replyTask = nil
        messages = []
        lastError = nil
        state = .idle
    }

    func cancelReply() {
        replyTask?.cancel()
    }

    // MARK: - Private

    /// Conversation history in API form. Empty assistant turns (failed replies) are dropped;
    /// consecutive user turns that leaves behind are merged by the API.
    private func apiHistory() -> [AnthropicClient.Message] {
        messages
            .filter { !($0.role == .assistant && $0.text.isEmpty) }
            .map { AnthropicClient.Message(role: $0.role.rawValue, content: $0.text) }
    }

    private func append(_ chunk: String, to id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += chunk
        if state == .thinking { state = .talking }
    }

    private func finishReply(_ id: UUID, error: Error?) {
        replyTask = nil
        if let index = messages.firstIndex(where: { $0.id == id }), messages[index].text.isEmpty {
            messages.remove(at: index)
        }
        if let error, !(error is CancellationError), (error as? URLError)?.code != .cancelled {
            lastError = error.localizedDescription
        }
        state = .idle
    }
}
