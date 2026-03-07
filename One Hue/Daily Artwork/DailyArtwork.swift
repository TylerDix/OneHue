import SwiftUI

/// The three states a daily artwork moves through.
enum ArtworkPhase: Equatable {
    case pristine    // Muted SVG visible, "tap to begin"
    case painting    // Elements fillable, palette visible
    case complete    // Fully colored artwork revealed
}
