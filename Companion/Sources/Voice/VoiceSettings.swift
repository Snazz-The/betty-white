import AVFoundation
import Foundation
import Observation

/// User preferences for voice in and out, persisted in UserDefaults.
@MainActor
@Observable
final class VoiceSettings {
    private enum Key {
        static let muted = "voice.muted"
        static let speakTypedReplies = "voice.speakTypedReplies"
        static let voiceIdentifier = "voice.voiceIdentifier"
        static let rate = "voice.rate"
        static let hotKey = "voice.hotKey"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// When muted, nothing is spoken aloud.
    var isMuted: Bool { didSet { defaults.set(isMuted, forKey: Key.muted) } }
    /// Replies to voice messages are always spoken (unless muted); this adds typed ones.
    var speakTypedReplies: Bool { didSet { defaults.set(speakTypedReplies, forKey: Key.speakTypedReplies) } }
    /// nil means the system default voice.
    var voiceIdentifier: String? { didSet { defaults.set(voiceIdentifier, forKey: Key.voiceIdentifier) } }
    var rate: Float { didSet { defaults.set(rate, forKey: Key.rate) } }
    var hotKey: HotKeyCombo {
        didSet { defaults.set(try? JSONEncoder().encode(hotKey), forKey: Key.hotKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isMuted = defaults.bool(forKey: Key.muted)
        speakTypedReplies = defaults.bool(forKey: Key.speakTypedReplies)
        voiceIdentifier = defaults.string(forKey: Key.voiceIdentifier)
        rate = defaults.object(forKey: Key.rate) as? Float ?? AVSpeechUtteranceDefaultSpeechRate
        hotKey = defaults.data(forKey: Key.hotKey).flatMap { try? JSONDecoder().decode(HotKeyCombo.self, from: $0) }
            ?? .defaultPushToTalk
    }

    func shouldSpeak(_ origin: MessageOrigin) -> Bool {
        !isMuted && (origin == .voice || speakTypedReplies)
    }
}
