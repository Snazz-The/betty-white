import AppKit
import AVFoundation
import Speech

/// Microphone + speech recognition authorization.
enum VoicePermissions {
    enum Problem: Equatable {
        case microphoneDenied
        case speechDenied
        case speechRestricted

        var message: String {
            switch self {
            case .microphoneDenied: return "Companion can't use the microphone. Allow it in System Settings › Privacy & Security › Microphone."
            case .speechDenied: return "Speech recognition is off for Companion. Allow it in System Settings › Privacy & Security › Speech Recognition."
            case .speechRestricted: return "Speech recognition is restricted on this Mac."
            }
        }

        var settingsURL: URL? {
            switch self {
            case .microphoneDenied: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
            case .speechDenied: return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
            case .speechRestricted: return nil
            }
        }
    }

    /// Asks for whatever hasn't been decided yet. Returns the first problem, or nil when everything is allowed.
    static func ensureAuthorized() async -> Problem? {
        switch await speechStatus() {
        case .authorized: break
        case .restricted: return .speechRestricted
        default: return .speechDenied
        }
        return await microphoneAllowed() ? nil : .microphoneDenied
    }

    private static func speechStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    private static func microphoneAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }
}
