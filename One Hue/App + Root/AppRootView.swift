import SwiftUI

struct AppRootView: View {
    @StateObject private var store = ColoringStore()

    var body: some View {
        HomeView(store: store)
            .preferredColorScheme(.dark)
    }
}
