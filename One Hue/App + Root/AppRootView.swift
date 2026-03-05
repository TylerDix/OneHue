import SwiftUI
import Combine

struct AppRootView: View {
    @StateObject private var store = DailyArtworkStore()

    var body: some View {
        TodayView(store: store)
            .preferredColorScheme(.dark)
    }
}

