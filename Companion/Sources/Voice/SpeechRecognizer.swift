import AVFoundation
import Speech

/// Push-to-talk speech-to-text: `start()` on key down, `stop()` on key up.
/// Uses on-device recognition when the current language supports it.
@MainActor
final class SpeechRecognizer {
    enum RecognizerError: LocalizedError {
        case unavailable
        case noMicrophone

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Speech recognition isn't available right now."
            case .noMicrophone: return "No microphone input was found."
            }
        }
    }

    /// Called with the running transcript as you speak.
    var onPartial: (@MainActor (String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: .current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var transcript = ""
    private var finalWaiter: CheckedContinuation<String, Never>?

    var isRecording: Bool { engine.isRunning }

    func start() throws {
        guard let recognizer, recognizer.isAvailable else { throw RecognizerError.unavailable }
        cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { throw RecognizerError.noMicrophone }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tap(appendingTo: request))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }

        transcript = ""
        self.request = request
        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler { [weak self] text, isFinal in
            self?.handle(text: text, isFinal: isFinal)
        })
    }

    /// Stops listening and returns the final transcript (waits briefly for the recognizer to finish).
    func stop() async -> String {
        stopAudio()
        request?.endAudio()
        guard task != nil else { return transcript }
        return await withCheckedContinuation { continuation in
            finalWaiter = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                self?.resolve()
            }
        }
    }

    func cancel() {
        stopAudio()
        task?.cancel()
        resolve()
    }

    // MARK: - Private

    private func stopAudio() {
        guard engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    private func handle(text: String?, isFinal: Bool) {
        if let text, !text.isEmpty {
            transcript = text
            onPartial?(text)
        }
        if isFinal { resolve() }
    }

    private func resolve() {
        task = nil
        request = nil
        finalWaiter?.resume(returning: transcript)
        finalWaiter = nil
    }

    // These run on audio / recognizer threads, so they're built outside the main actor.

    private nonisolated static func tap(appendingTo request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    private nonisolated static func resultHandler(
        _ deliver: @escaping @MainActor (String?, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = (result?.isFinal ?? false) || error != nil
            Task { @MainActor in deliver(text, isFinal) }
        }
    }
}
