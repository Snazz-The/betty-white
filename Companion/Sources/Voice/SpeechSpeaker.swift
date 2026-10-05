import AVFoundation

/// Speaks reply text as it streams in, one sentence at a time.
@MainActor
final class SpeechSpeaker: NSObject {
    /// Called when speech starts or stops, so the brain can stay in its talking state.
    var onSpeakingChanged: (@MainActor (Bool) -> Void)?

    var voiceIdentifier: String?
    /// Between AVSpeechUtteranceMinimumSpeechRate and AVSpeechUtteranceMaximumSpeechRate.
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    private let synthesizer = AVSpeechSynthesizer()
    private var buffer = ""
    /// Utterances handed to the synthesizer that haven't finished yet.
    private var queued = Set<ObjectIdentifier>() {
        didSet {
            if oldValue.isEmpty != queued.isEmpty { onSpeakingChanged?(!queued.isEmpty) }
        }
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var isSpeaking: Bool { !queued.isEmpty }

    /// Adds streamed text; any complete sentences are spoken right away.
    func enqueue(_ chunk: String) {
        buffer += chunk
        if let sentences = SentenceSplitter.takeCompleteSentences(from: &buffer) {
            speak(sentences)
        }
    }

    /// Speaks whatever is left once the reply is complete.
    func flush() {
        let rest = buffer
        buffer = ""
        speak(rest)
    }

    func stop() {
        buffer = ""
        synthesizer.stopSpeaking(at: .immediate)
        queued.removeAll()
    }

    private func speak(_ text: String) {
        let clean = SentenceSplitter.stripMarkdown(text)
        guard !clean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: clean)
        utterance.rate = rate
        if let voiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        }
        queued.insert(ObjectIdentifier(utterance))
        synthesizer.speak(utterance)
    }

    private func utteranceEnded(_ id: ObjectIdentifier) {
        queued.remove(id)
    }
}

extension SpeechSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(id) }
    }
}

/// Text helpers for speaking streamed replies.
enum SentenceSplitter {
    /// Removes and returns everything up to the last sentence boundary, or nil if there isn't one yet.
    static func takeCompleteSentences(from buffer: inout String) -> String? {
        var cut: String.Index?
        var index = buffer.startIndex
        while index < buffer.endIndex {
            let next = buffer.index(after: index)
            let char = buffer[index]
            if char == "\n" {
                cut = next
            } else if ".!?".contains(char), next < buffer.endIndex, buffer[next].isWhitespace {
                cut = next
            }
            index = next
        }
        guard let cut else { return nil }
        let sentences = String(buffer[..<cut])
        buffer = String(buffer[cut...])
        return sentences
    }

    /// Drops markdown punctuation that would otherwise be read aloud.
    static func stripMarkdown(_ text: String) -> String {
        var result = text
        for token in ["**", "__", "`", "#", "*", "_"] {
            result = result.replacingOccurrences(of: token, with: "")
        }
        return result
    }
}
