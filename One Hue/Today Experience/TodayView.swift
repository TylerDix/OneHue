import SwiftUI

struct TodayView: View {
    @StateObject private var store = ColoringStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings    = false
    @State private var showCompletion  = false
    @State private var showShareSheet  = false
    @State private var showGallery     = false
    @State private var shareImage: UIImage? = nil
    @AppStorage("onehue.onboardingShown") private var onboardingShown = false
    @State private var showOnboarding = false

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
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(12)
                                    .background(Circle().fill(.black.opacity(0.35)))
                                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Find next unfilled region")
                            .padding(16)
                            .transition(.opacity)
                        }
                    }
                    .accessibilityLabel("Coloring canvas, \(store.document.title)")
                    .accessibilityHint("Tap colored regions to fill them")

                // Palette — swatches animate away on completion but
                // the container stays so the canvas doesn't jump.
                PaletteView(
                    groups: store.document.groups,
                    selectedIndex: $store.selectedGroupIndex,
                    filledElements: store.filledElements,
                    isComplete: store.isComplete
                )
                .padding(.top, 8)
                .padding(.bottom, 12)
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
                    artworkID: store.currentArtwork.id,
                    completionService: CompletionService.shared,
                    onShare: { shareCompletedArtwork() },
                    onNext: { loadNextArtwork() }
                )
                .transition(.opacity)
            }

            // First-run onboarding
            if showOnboarding {
                OnboardingOverlay {
                    onboardingShown = true
                    withAnimation(.easeOut(duration: 0.4)) { showOnboarding = false }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            if store.phase == .complete {
                showCompletion = true
            }
            if !onboardingShown && store.phase != .complete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeIn(duration: 0.5)) { showOnboarding = true }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                store.persistNow()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showGallery) {
            GalleryView(store: store)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image, "One Hue — \(store.currentArtwork.displayName)"])
            }
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

            if store.canUndo {
                Button { store.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(10)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo last fill")
                .transition(.opacity)
            }

            Button { showGallery = true } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Gallery")

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Helpers

    private var hasUnfilledInSelectedGroup: Bool {
        guard store.selectedGroupIndex < store.document.groups.count else { return false }
        let group = store.document.groups[store.selectedGroupIndex]
        return group.elementIndices.contains(where: { !store.filledElements.contains($0) })
    }

    // MARK: - Next Artwork

    private func loadNextArtwork() {
        withAnimation { showCompletion = false }
        store.nextArtwork()
    }

    // MARK: - Completion Sequence

    private func beginCompletionSequence() {
        guard !showCompletion else { return }

        // 0.0s — Canvas freezes (phase = .complete disables gestures).
        //        Numbers dissolve (CanvasView handles this, ~1s).

        // 1.0s — Slowly drift back to center (1.5s ease).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            store.triggerCompletionDrift()
        }

        // 3.0s — Overlay gently appears.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 1.0)) { showCompletion = true }
        }
    }

    private func resetCompletionSequence() {
        showCompletion = false
    }

    // MARK: - Share

    private func shareCompletedArtwork() {
        let allFilled = Set(0..<store.document.elements.count)
        let canvasWidth: CGFloat = 1024
        let canvasHeight = canvasWidth / store.document.aspectRatio

        let caption = shareCaption

        let renderer = ImageRenderer(content:
            VStack(spacing: 0) {
                SVGCanvasRenderer(
                    document: store.document,
                    filledElements: allFilled,
                    selectedGroupIndex: 0,
                    showNumbers: false,
                    zoomLevel: 1.0,
                    activeAnimations: [],
                    flashTick: 0
                )
                .frame(width: canvasWidth, height: canvasHeight)

                Text(caption)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .background(Color.black)
        )
        renderer.scale = 2.0
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }

    private var shareCaption: String {
        let title = store.currentArtwork.displayName

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = formatter.string(from: Date())

        if let count = CompletionService.shared.globalCount, count > 0 {
            let formatted = count.formatted(.number)
            return "\(title) — \(date) — Colored by \(formatted) people"
        }
        return "\(title) — \(date)"
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Onboarding Overlay

private struct OnboardingOverlay: View {
    let onDismiss: () -> Void
    @State private var step = 0

    private let steps: [(icon: String, title: String, body: String)] = [
        ("paintbrush.pointed", "Tap to fill", "Each region has a number. Select a color from the palette, then tap matching regions to fill them."),
        ("scope", "Find regions", "Lost a region? Tap the scope button to zoom to the next unfilled area for your selected color."),
        ("arrow.uturn.backward", "Undo mistakes", "Tapped the wrong spot? Use the undo button in the header to reverse your last fill."),
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            let s = steps[step]

            VStack(spacing: 18) {
                Image(systemName: s.icon)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))

                Text(s.title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))

                Text(s.body)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 300)
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            // Step indicators
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle()
                        .fill(.white.opacity(i == step ? 0.9 : 0.25))
                        .frame(width: 7, height: 7)
                }
            }

            // Action button
            Button {
                if step < steps.count - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
                } else {
                    onDismiss()
                }
            } label: {
                Text(step < steps.count - 1 ? "Next" : "Start Coloring")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)

            // Skip
            if step < steps.count - 1 {
                Button("Skip") { onDismiss() }
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                    .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85).ignoresSafeArea())
    }
}

// MARK: - Previews

#Preview("Pristine") {
    TodayView().preferredColorScheme(.dark)
}

#Preview("Onboarding") {
    OnboardingOverlay(onDismiss: {})
        .preferredColorScheme(.dark)
}
