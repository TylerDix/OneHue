#if DEBUG
import Foundation

/// Shared debug toggles — read by views, written by TesterPanel.
/// Lives only in DEBUG builds; production uses compile-time defaults.
final class DebugSettings {
    static let shared = DebugSettings()

    /// true = 5-star + comment field, false = thumbs up/down.
    var useStarRating: Bool = true
}
#endif
