import Foundation
import Observation

/// Gets told about reply text as it streams, e.g. to speak it aloud.
@MainActor
protocol ReplyObserver: AnyObject {
    func replyDidReceive(_ chunk: String, origin: MessageOrigin)
    func replyDidFinish(origin: MessageOrigin)
    func replyDidCancel()
}

/// Owns the conversation and the companion's state. The menu bar chat, the desktop pet,
/// and the voice layer all observe this one object.
@MainActor
@Observable
final class CompanionBrain {
    private enum ReplyPhase { case idle, waiting, streaming }

    private(set) var messages: [ChatMessage] = []
    var lastError: String?

    /// Set by the voice layer while the push-to-talk key is held.
    var isListening = false
    /// Set by the voice layer while a reply is being spoken.
    var isSpeaking = false

    private var phase: ReplyPhase = .idle

    @ObservationIgnored weak var replyObserver: ReplyObserver?
    @ObservationIgnored private var replyTask: Task<Void, Never>?
    @ObservationIgnored private var currentReplyID: UUID?
    @ObservationIgnored private let personality: String
    @ObservationIgnored private let apiKeyProvider: @MainActor () -> String?

    init(
        personality: String = Personality.load(),
        apiKeyProvider: @escaping @MainActor () -> String? = { ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] }
    ) {
        self.personality = personality
        self.apiKeyProvider = apiKeyProvider
    }

    var state: CompanionState {
        if isListening { return .listening }
        switch phase {
        case .waiting: return .thinking
        case .streaming: return .talking
        case .idle: return isSpeaking ? .talking : .idle
        }
    }

    /// True while a reply is being requested or streamed.
    var isBusy: Bool { phase != .idle }

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
        currentReplyID = reply.id
        phase = .waiting

        let client = AnthropicClient(apiKey: apiKey)
        let system = Personality.systemPrompt(base: personality, origin: origin)
        let maxTokens = origin == .voice ? Config.voiceMaxTokens : Config.typedMaxTokens

        replyTask = Task { [weak self] in
            do {
                for try await chunk in client.streamReply(system: system, messages: history, maxTokens: maxTokens) {
                    self?.append(chunk, to: reply.id, origin: origin)
                }
                self?.finishReply(reply.id, origin: origin, error: nil)
            } catch {
                self?.finishReply(reply.id, origin: origin, error: error)
            }
        }
    }

    /// Stops any in-flight reply and speech, and forgets the conversation.
    func clear() {
        cancelReply()
        replyTask = nil
        currentReplyID = nil
        messages = []
        lastError = nil
        phase = .idle
    }

    /// Stops the current reply (and any speech of it).
    func cancelReply() {
        replyTask?.cancel()
        replyObserver?.replyDidCancel()
    }

    // MARK: - Private

    /// Conversation history in API form. Empty assistant turns (failed replies) are dropped;
    /// consecutive user turns that leaves behind are merged by the API.
    private func apiHistory() -> [AnthropicClient.Message] {
        messages
            .filter { !($0.role == .assistant && $0.text.isEmpty) }
            .map { AnthropicClient.Message(role: $0.role.rawValue, content: $0.text) }
    }

    private func append(_ chunk: String, to id: UUID, origin: MessageOrigin) {
        guard id == currentReplyID, let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += chunk
        phase = .streaming
        replyObserver?.replyDidReceive(chunk, origin: origin)
    }

    private func finishReply(_ id: UUID, origin: MessageOrigin, error: Error?) {
        // A reply cancelled by clear() can finish after a newer one has started.
        guard id == currentReplyID else { return }
        currentReplyID = nil
        replyTask = nil
        if let index = messages.firstIndex(where: { $0.id == id }), messages[index].text.isEmpty {
            messages.remove(at: index)
        }
        let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled
        if let error, !cancelled {
            lastError = error.localizedDescription
        }
        if !cancelled { replyObserver?.replyDidFinish(origin: origin) }
        phase = .idle
    }
}
