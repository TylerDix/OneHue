import SwiftUI

struct TodayView: View {
    @StateObject private var store = DailyArtworkStore()

    @State private var showSettings = false
    @State private var showCompletion = false
    @State private var wrongColorToast = false

    // Separate opacity controls for the completion sequence:
    // - Chrome (header, palette) fades to 0
    // - Canvas dims but stays visible as backdrop
    @State private var chromeOpacity: CGFloat = 1.0
    @State private var canvasOpacity: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 16) {
                header.opacity(chromeOpacity)

                CanvasView(store: store) {
                    showWrongColorToast()
                }
                .padding(.horizontal, 18)
                .opacity(canvasOpacity)
                // Disable interaction once complete
                .allowsHitTesting(!store.isComplete)

                PaletteView(
                    palette: store.artwork.palette,
                    selectedIndex: $store.selectedColorIndex,
                    filledIDs: store.filledRegionIDs,
                    regions: store.artwork.regions,
                    isComplete: store.isComplete
                )
                .opacity(chromeOpacity)

                Spacer(minLength: 10)
            }
            .padding(.top, 14)
            .onChange(of: store.isComplete) { _, complete in
                if complete { beginCompletionSequence() }
                else { resetCompletionSequence() }
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
                            .fill(.black.opacity(0.55))
                            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                    )
                    .transition(.opacity)
                    .padding(.top, 56)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            // Completion — floats over the dimmed artwork
            if showCompletion {
                CompletionOverlayView(
                    message: store.artwork.completionMessage,
                    count: 12_847  // TODO: Replace with live Supabase counter
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
            Text(store.artwork.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text(store.progressText)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Completion Sequence

    private func beginCompletionSequence() {
        guard !showCompletion else { return }

        // Step 1: Fade out chrome (header, palette) — 400ms
        withAnimation(.easeOut(duration: 0.4)) {
            chromeOpacity = 0.0
        }

        // Step 2: Dim the artwork to a quiet backdrop — starts slightly after, 600ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.6)) {
                canvasOpacity = 0.35
            }
        }

        // Step 3: Bring in the completion overlay — after artwork has dimmed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.5)) {
                showCompletion = true
            }
        }
    }

    private func resetCompletionSequence() {
        showCompletion = false
        chromeOpacity = 1.0
        canvasOpacity = 1.0
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
