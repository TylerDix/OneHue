import SwiftUI

struct FillPulse: Equatable {
    let regionID: Int
    let trigger: UUID
}

enum FillAnimation {
    static let duration: Double = 0.20
    static let bloomScale: CGFloat = 1.035
}
