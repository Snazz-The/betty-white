import SwiftUI

/// The chat window shown from the menu bar icon.
struct ChatPopoverView: View {
    @Environment(CompanionBrain.self) private var brain
    @Environment(APIKeyStore.self) private var keys
    @Environment(\.openSettings) private var openSettings
    @State private var draft = ""
    @FocusState private var inputFocused: Bool
    @AppStorage(PetVisibility.key) private var petVisible = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if keys.hasKey {
                transcript
                if let error = brain.lastError {
                    ErrorBanner(text: error) { brain.lastError = nil }
                }
                Divider()
                inputBar
            } else {
                OnboardingView()
            }
        }
        .frame(width: 380, height: 520)
        .onAppear { inputFocused = true }
    }

    private var header: some View {
        HStack {
            Text("Companion").font(.headline)
            if brain.state == .thinking {
                ProgressView().controlSize(.small)
            }
            Spacer()
            Button {
                brain.clear()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear conversation")
            .disabled(brain.messages.isEmpty)

            Menu {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                .keyboardShortcut(",")
                Toggle("Show Desktop Pet", isOn: $petVisible)
                Divider()
                Button("Quit Companion") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if brain.messages.isEmpty {
                        Text("Say hello.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(brain.messages) { message in
                        MessageBubble(message: message).id(message.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: brain.messages.last?.text) {
                if let id = brain.messages.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $draft)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .onSubmit(send)
            if brain.isBusy {
                Button(action: brain.cancelReply) {
                    Image(systemName: "stop.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .help("Stop")
            } else {
                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
    }

    private func send() {
        guard !brain.isBusy else { return }
        brain.send(draft)
        draft = ""
    }
}

private struct ErrorBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: dismiss) { Image(systemName: "xmark") }.buttonStyle(.borderless)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
    }
}
