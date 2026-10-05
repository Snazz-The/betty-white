import SwiftUI

@main
struct CompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            ChatPopoverView()
                .environment(appDelegate.brain)
                .environment(appDelegate.keys)
        } label: {
            Image(systemName: appDelegate.brain.state.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appDelegate.brain)
                .environment(appDelegate.keys)
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
