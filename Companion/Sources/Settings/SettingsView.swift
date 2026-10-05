import SwiftUI

/// The Settings window (⌘, from the chat menu).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 460)
        .padding(20)
    }
}

struct GeneralSettingsView: View {
    @Environment(APIKeyStore.self) private var keys

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
        }
        .formStyle(.grouped)
    }
}
