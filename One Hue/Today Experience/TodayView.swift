import SwiftUI

struct TodayView: View {
    @StateObject private var store = ColoringStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings   = false
    @State private var showCompletion = false
    @State private var chromeOpacity: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                header
                    .opacity(chromeOpacity)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Canvas
                CanvasView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Palette — only during painting
                if store.phase == .painting {
                    PaletteView(
                        groups: store.document.groups,
                        selectedIndex: $store.selectedGroupIndex,
                        filledElements: store.filledElements,
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
                    if phase == .painting { resetCompletionSequence() }
                }
            }

            // Completion overlay
            if showCompletion {
                CompletionOverlayView(
                    message: store.document.completionMessage,
                    onDismiss: {
                        store.resetProgress()
                        resetCompletionSequence()
                    }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(store.document.title)
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
}

// MARK: - Previews

#Preview("Pristine") {
    TodayView().preferredColorScheme(.dark)
}
