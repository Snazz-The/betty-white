import SwiftUI

/// Paste-and-save control for the API key, used by first-run setup and Settings.
struct APIKeyField: View {
    @Environment(APIKeyStore.self) private var keys
    @State private var entry = ""
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SecureField(keys.isStoredInKeychain ? "Replace key" : "sk-ant-…", text: $entry)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(save)
                Button("Save", action: save)
                    .disabled(entry.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if failed {
                Text("Couldn't save to the Keychain.").font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func save() {
        failed = !keys.save(entry)
        if !failed { entry = "" }
    }
}
