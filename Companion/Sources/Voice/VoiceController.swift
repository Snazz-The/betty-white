import AppKit
import Observation

/// Push-to-talk in, spoken replies out. Holds the hotkey, recognizer, and speaker,
/// and keeps the brain's listening/speaking flags in sync.
@MainActor
@Observable
final class VoiceController {
    /// What you're saying, while the hotkey is held.
    private(set) var liveTranscript = ""
    /// Set when microphone or speech permission is missing.
    private(set) var permissionProblem: VoicePermissions.Problem?
    /// False if the hotkey couldn't be registered (e.g. another app owns it).
    private(set) var hotKeyRegistered = false

    @ObservationIgnored private let brain: CompanionBrain
    @ObservationIgnored let settings: VoiceSettings
    @ObservationIgnored private let hotKey = GlobalHotKey()
    @ObservationIgnored private let recognizer = SpeechRecognizer()
    @ObservationIgnored private let speaker = SpeechSpeaker()
    @ObservationIgnored private var keyHeld = false

    init(brain: CompanionBrain, settings: VoiceSettings) {
        self.brain = brain
        self.settings = settings
        brain.replyObserver = self

        speaker.onSpeakingChanged = { [weak brain] speaking in brain?.isSpeaking = speaking }
        recognizer.onPartial = { [weak self] text in self?.liveTranscript = text }
        hotKey.onPress = { [weak self] in self?.pushToTalkPressed() }
        hotKey.onRelease = { [weak self] in self?.pushToTalkReleased() }
        applyHotKey()
        observeSettings()
    }

    /// Re-registers the hotkey from settings.
    func applyHotKey() {
        hotKeyRegistered = hotKey.register(settings.hotKey)
    }

    func stopSpeaking() {
        speaker.stop()
    }

    /// Says a short line with the current voice settings.
    func preview() {
        speaker.stop()
        speaker.enqueue("Hi! This is how I sound.")
        speaker.flush()
    }

    func openPermissionSettings() {
        if let url = permissionProblem?.settingsURL { NSWorkspace.shared.open(url) }
    }

    func dismissPermissionProblem() {
        permissionProblem = nil
    }

    // MARK: - Push to talk

    private func pushToTalkPressed() {
        guard !keyHeld else { return } // ignore key repeat
        keyHeld = true
        speaker.stop()
        if brain.isBusy { brain.cancelReply() }

        Task {
            if let problem = await VoicePermissions.ensureAuthorized() {
                permissionProblem = problem
                return
            }
            permissionProblem = nil
            // The key may have been released while a permission prompt was up.
            guard keyHeld else { return }
            do {
                liveTranscript = ""
                try recognizer.start()
                brain.isListening = true
            } catch {
                brain.lastError = error.localizedDescription
            }
        }
    }

    private func pushToTalkReleased() {
        keyHeld = false
        guard recognizer.isRecording else { return }
        Task {
            let text = await recognizer.stop()
            brain.isListening = false
            liveTranscript = ""
            brain.send(text, origin: .voice)
        }
    }

    // MARK: - Settings

    private func observeSettings() {
        withObservationTracking {
            _ = settings.isMuted
            _ = settings.voiceIdentifier
            _ = settings.rate
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.settings.isMuted { self.speaker.stop() }
                self.speaker.voiceIdentifier = self.settings.voiceIdentifier
                self.speaker.rate = self.settings.rate
                self.observeSettings()
            }
        }
        speaker.voiceIdentifier = settings.voiceIdentifier
        speaker.rate = settings.rate
    }
}

extension VoiceController: ReplyObserver {
    func replyDidReceive(_ chunk: String, origin: MessageOrigin) {
        guard settings.shouldSpeak(origin) else { return }
        speaker.enqueue(chunk)
    }

    func replyDidFinish(origin: MessageOrigin) {
        guard settings.shouldSpeak(origin) else { return }
        speaker.flush()
    }

    func replyDidCancel() {
        speaker.stop()
    }
}
