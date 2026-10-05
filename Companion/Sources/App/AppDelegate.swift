import AppKit

/// Owns the long-lived pieces of the app. SwiftUI scenes read them from here.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let keys = APIKeyStore()
    let voiceSettings = VoiceSettings()
    let launchAtLogin = LaunchAtLogin()
    private(set) lazy var brain = CompanionBrain(apiKeyProvider: { [keys] in keys.currentKey })
    private(set) lazy var voice = VoiceController(brain: brain, settings: voiceSettings)
    private var pet: PetWindowController?
    private var defaultsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isRunningTests else { return }
        _ = voice // registers the push-to-talk hotkey
        pet = PetWindowController(brain: brain)
        syncPetVisibility()
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncPetVisibility() }
        }
    }

    private func syncPetVisibility() {
        guard let pet else { return }
        if PetVisibility.isVisible, !pet.isVisible {
            pet.show()
        } else if !PetVisibility.isVisible, pet.isVisible {
            pet.hide()
        }
    }

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
