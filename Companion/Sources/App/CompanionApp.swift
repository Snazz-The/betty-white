import SwiftUI

@main
struct CompanionApp: App {
    @State private var brain = CompanionBrain()

    var body: some Scene {
        MenuBarExtra {
            ChatPopoverView()
                .environment(brain)
        } label: {
            Image(systemName: brain.state.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
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
