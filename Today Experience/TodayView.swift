import SwiftUI

struct TodayView: View {
    @StateObject private var store = DailyArtworkStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings    = false
    @State private var showCompletion  = false
    @State private var wrongColorToast = false
    @State private var chromeOpacity: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header — always visible
                header
                    .opacity(chromeOpacity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Canvas — fills remaining space between header and palette
                CanvasView(store: store) { showWrongColorToast() }
                    .aspectRatio(store.artwork.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Palette — only during painting
                if store.phase == .painting {
                    PaletteView(
                        palette: store.artwork.palette,
                        selectedIndex: $store.selectedColorIndex,
                        filledCells: store.filledCells,
                        artwork: store.artwork,
                        isComplete: store.isComplete
                    )
                    .opacity(chromeOpacity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                }
            }
            .onChange(of: store.phase) { _, phase in
                withAnimation {
                    if phase == .complete { beginCompletionSequence() }
                    if phase == .pristine { resetCompletionSequence() }
                }
            }

            // "Not that one" toast
            if wrongColorToast && !showCompletion {
                Text("Not that one")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.6))
                            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                    )
                    .transition(.opacity)
                    .padding(.top, 64)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            // Completion overlay
            if showCompletion {
                CompletionOverlayView(
                    message: store.artwork.completionMessage,
                    count: store.globalCount,
                    onDebugDismiss: {
                        store.resetThisDayProgress()
                        resetCompletionSequence()
                    }
                )
                .transition(.opacity)
            }
        }
        .opacity(handoffOpacity)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.onForeground() }
        }
        .onChange(of: store.handoffPhase) { _, phase in
            if phase == .fadingIn { resetCompletionSequence() }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }

    // MARK: - Handoff

    private var handoffOpacity: CGFloat {
        store.handoffPhase == .fadingOut ? 0.0 : 1.0
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(store.artwork.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            if store.phase == .painting {
                Text(store.progressText)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .transition(.opacity)
            }

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Completion Sequence

    private func beginCompletionSequence() {
        guard !showCompletion else { return }
        withAnimation(.easeOut(duration: 0.5)) { chromeOpacity = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.6)) { showCompletion = true }
        }
    }

    private func resetCompletionSequence() {
        showCompletion = false
        withAnimation(.easeIn(duration: 0.3)) { chromeOpacity = 1.0 }
    }

    // MARK: - Wrong Color Toast

    private func showWrongColorToast() {
        guard !wrongColorToast else { return }
        withAnimation(.easeOut(duration: 0.12)) { wrongColorToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.2)) { wrongColorToast = false }
        }
    }
}

// MARK: - Previews

#Preview("Pristine") {
    TodayView().preferredColorScheme(.dark)
}

#Preview("Painting") {
    let store = DailyArtworkStore()
    store.beginPainting()
    return TodayView().preferredColorScheme(.dark)
}
