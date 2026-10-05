import SwiftUI

@main
struct CompanionApp: App {
    @State private var keys: APIKeyStore
    @State private var brain: CompanionBrain

    init() {
        let keys = APIKeyStore()
        _keys = State(initialValue: keys)
        _brain = State(initialValue: CompanionBrain(apiKeyProvider: { keys.currentKey }))
    }

    var body: some Scene {
        MenuBarExtra {
            ChatPopoverView()
                .environment(brain)
                .environment(keys)
        } label: {
            Image(systemName: brain.state.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(brain)
                .environment(keys)
        }
    }
}

extension CompanionState {
    var menuBarSymbol: String {
        switch self {
        case .idle: return "bubble.left.fill"
        case .listening: return "ear.fill"
        case .thinking: return "ellipsis.bubble.fill"
        case .talking: return "text.bubble.fill"
        }
    }
}
