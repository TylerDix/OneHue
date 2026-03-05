import SwiftUI

struct DailyArtwork: Identifiable {
    let id: String
    let title: String
    let completionMessage: String
    let palette: [Color]
    let regions: [Region]
}
