import SwiftUI

struct FillPulse: Equatable {
    let regionID: Int
    let trigger: UUID
}

enum FillAnimation {
    /// Duration for the color fade when a region is filled.
    /// Target from spec: 180–220ms. Using 200ms as a clean middle.
    static let duration: Double = 0.20
}
