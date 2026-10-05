import SwiftUI

/// Shown in the popover until an API key is available.
struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "key.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            Text("Welcome to Companion").font(.title3.bold())
            Text("Paste your Anthropic API key to get started. It's stored in your Keychain.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            APIKeyField()
            Link("Get a key at console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                .font(.caption)
        }
        .padding(24)
        .frame(maxHeight: .infinity)
    }
}
