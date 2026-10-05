import SwiftUI

/// Hosts the artwork, follows the brain's state, and drags the window.
struct PetView: View {
    @Environment(CompanionBrain.self) private var brain
    let artwork: PetArtwork
    let onDrag: () -> Void
    let onDragEnd: () -> Void
    let menu: () -> AnyView

    var body: some View {
        artwork.view(for: brain.state)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in onDrag() }
                    .onEnded { _ in onDragEnd() }
            )
            .contextMenu { menu() }
            .animation(.spring(duration: 0.3), value: brain.state)
    }
}
