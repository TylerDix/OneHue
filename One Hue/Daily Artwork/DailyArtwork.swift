import SwiftUI

/// The complete data for one day's color-by-number artwork.
/// Contains the vector regions, the curated color palette, and metadata.
struct DailyArtwork: Identifiable {
    let id: String                  // e.g. "2026-03-05"
    let title: String               // e.g. "Peace"
    let subject: String             // e.g. "peace symbol"
    let completionMessage: String   // includes [count] placeholder
    let palette: [Color]            // 8–20 curated colors
    let regions: [Region]           // 150–400 vector regions
    let viewBoxWidth: CGFloat       // SVG viewBox width
    let viewBoxHeight: CGFloat      // SVG viewBox height

    /// Aspect ratio of the original artwork (used for layout)
    var aspectRatio: CGFloat {
        guard viewBoxHeight > 0 else { return 4.0 / 3.0 }
        return viewBoxWidth / viewBoxHeight
    }
}
