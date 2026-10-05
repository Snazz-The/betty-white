import SwiftUI

/// The art layer for the desktop pet. Swap in real art by writing a new conformer
/// (sprite sheets, Lottie, Rive, images…) and returning it from `PetArtworkProvider.current`.
@MainActor
protocol PetArtwork {
    /// Size of the character's window in points.
    var size: CGSize { get }

    /// The character drawn for a given state. Animate inside the view as you like.
    func view(for state: CompanionState) -> AnyView

    /// Whether a point (in the character's coordinate space, origin top-left) is on the
    /// character. Clicks anywhere else pass through to whatever is underneath.
    func contains(_ point: CGPoint) -> Bool
}

enum PetArtworkProvider {
    @MainActor static var current: PetArtwork { BlobPetArtwork() }
}
