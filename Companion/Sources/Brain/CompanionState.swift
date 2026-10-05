import Foundation

/// The shared state every part of the app (menu bar, pet, voice) reacts to.
enum CompanionState: Equatable {
    case idle
    case listening
    case thinking
    case talking
}
