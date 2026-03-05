import SwiftUI

/// A single colorable region within a daily artwork.
/// Each region is a closed vector path that the user fills with the correct color.
struct Region: Identifiable {
    let id: Int
    /// The number displayed on the region (matches palette swatch label)
    let number: Int
    /// Index into the artwork's palette array
    let colorIndex: Int
    /// The SwiftUI Path for rendering and hit-testing (normalized to 0...1 coordinate space)
    let path: Path
    /// Optional label center override; if nil, uses path bounding rect center
    let labelCenter: CGPoint?

    init(id: Int, number: Int, colorIndex: Int, path: Path, labelCenter: CGPoint? = nil) {
        self.id = id
        self.number = number
        self.colorIndex = colorIndex
        self.path = path
        self.labelCenter = labelCenter
    }
}
