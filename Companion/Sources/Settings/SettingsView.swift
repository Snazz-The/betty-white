import AVFoundation
import SwiftUI

/// The Settings window (⌘, from the chat menu).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            VoiceSettingsView()
                .tabItem { Label("Voice", systemImage: "waveform") }
        }
        .frame(width: 480)
        .padding(20)
    }
}

struct GeneralSettingsView: View {
    @Environment(APIKeyStore.self) private var keys
    @Environment(LaunchAtLogin.self) private var launchAtLogin
    @AppStorage(PetVisibility.key) private var petVisible = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Current key") {
                    if let masked = keys.maskedKey {
                        HStack {
                            Text(masked).monospaced()
                            if !keys.isStoredInKeychain {
                                Text("(from environment)").foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("None").foregroundStyle(.secondary)
                    }
                }
                APIKeyField()
                HStack {
                    Link("Get a key at console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                        .font(.caption)
                    Spacer()
                    if keys.isStoredInKeychain {
                        Button("Remove Key", role: .destructive) { keys.remove() }
                    }
                }
            } header: {
                Text("Anthropic API Key")
            } footer: {
                Text("Stored in your macOS Keychain. It never leaves this Mac except to talk to the Anthropic API.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("App") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.set($0) }
                ))
                if launchAtLogin.needsApproval {
                    HStack {
                        Text("Approve Companion in Login Items.").font(.caption)
                        Button("Open Login Items") { launchAtLogin.openLoginItemsSettings() }.controlSize(.small)
                    }
                }
                if let error = launchAtLogin.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Toggle("Show desktop pet", isOn: $petVisible)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
    }
}

struct VoiceSettingsView: View {
    @Environment(VoiceSettings.self) private var settings
    @Environment(VoiceController.self) private var voice

    private let voices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix(Locale.current.language.languageCode?.identifier ?? "en") }
        .sorted { $0.name < $1.name }

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Push to talk") {
                LabeledContent("Hold to talk") {
                    HotKeyRecorder(combo: $settings.hotKey) { recording in
                        if recording { voice.suspendHotKey() } else { voice.applyHotKey() }
                    }
                }
                if !voice.hotKeyRegistered {
                    Text("That shortcut is taken by another app. Pick a different one.")
                        .font(.caption).foregroundStyle(.red)
                }
            }

            Section("Spoken replies") {
                Toggle("Mute", isOn: $settings.isMuted)
                Toggle("Also speak replies to typed messages", isOn: $settings.speakTypedReplies)
                    .disabled(settings.isMuted)
                Picker("Voice", selection: $settings.voiceIdentifier) {
                    Text("System default").tag(String?.none)
                    ForEach(voices, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))").tag(String?.some(voice.identifier))
                    }
                }
                LabeledContent("Speed") {
                    Slider(value: $settings.rate, in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate)
                }
                Button("Preview") { voice.preview() }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.hotKey) { voice.applyHotKey() }
    }
}
