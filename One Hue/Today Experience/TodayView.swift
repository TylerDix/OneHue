import SwiftUI

struct TodayView: View {
    @StateObject private var store = ColoringStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings   = false
    @State private var showCompletion = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header — always visible so settings is accessible
                header
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Canvas
                CanvasView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottomTrailing) {
                        if store.phase == .painting && hasUnfilledInSelectedGroup {
                            Button { store.findNextUnfilled() } label: {
                                Image(systemName: "scope")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(10)
                                    .background(Circle().fill(.white.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .padding(16)
                            .transition(.opacity)
                        }
                    }

                // Palette — only during painting
                if store.phase == .painting {
                    PaletteView(
                        groups: store.document.groups,
                        selectedIndex: $store.selectedGroupIndex,
                        filledElements: store.filledElements,
                        isComplete: store.isComplete
                    )
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

            // Completion overlay — the app's resting state until midnight
            if showCompletion {
                CompletionOverlayView(
                    message: store.document.completionMessage,
                    completionService: CompletionService.shared
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            if store.phase == .complete {
                showCompletion = true
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
                .presentationDetents([.large])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Text(store.document.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                if store.phase == .complete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .transition(.opacity)
                }
            }

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

    // MARK: - Helpers

    private var hasUnfilledInSelectedGroup: Bool {
        let group = store.document.groups[store.selectedGroupIndex]
        return group.elementIndices.contains(where: { !store.filledElements.contains($0) })
    }

    // MARK: - Completion Sequence

    private func beginCompletionSequence() {
        guard !showCompletion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeIn(duration: 0.6)) { showCompletion = true }
        }
    }

    private func resetCompletionSequence() {
        showCompletion = false
    }
}

// MARK: - Previews

#Preview("Pristine") {
    TodayView().preferredColorScheme(.dark)
}
