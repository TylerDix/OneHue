import SwiftUI

struct TodayView: View {
    @StateObject private var store = ColoringStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings    = false
    @State private var showCompletion  = false
    @State private var skipReveal      = false
    @State private var showShareSheet  = false
    @State private var showGallery     = false
    @State private var shareImage: UIImage? = nil
    @AppStorage("onehue.onboardingShown") private var onboardingShown = false
    @State private var showOnboarding = false

    // Feature tooltips — shown once ever if the user hasn't discovered the feature
    @AppStorage("onehue.tip.peek") private var peekTipShown = false
    @AppStorage("onehue.tip.find") private var findTipShown = false
    @State private var showPeekTip = false
    @State private var showFindTip = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header — always visible so settings is accessible.
                // Uses a clear spacer to reserve its height in the VStack;
                // the actual header is overlaid in the ZStack above the
                // completion overlay so it stays tappable.
                Color.clear
                    .frame(height: 0)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Canvas
                CanvasView(store: store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottomTrailing) {
                        if store.phase == .painting && hasUnfilledInSelectedGroup && store.findUsesRemaining > 0 {
                            Button { dismissTips(); store.findNextUnfilled() } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "scope")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(12)
                                        .background(Circle().fill(.black.opacity(0.35)))
                                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                                    if store.findUsesRemaining <= 3 {
                                        Text("\(store.findUsesRemaining)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(Circle().fill(.white.opacity(0.25)))
                                            .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Find next unfilled region, \(store.findUsesRemaining) uses remaining")
                            .overlay(alignment: .leading) {
                                if showFindTip {
                                    FeatureTip(text: "Find hidden regions")
                                        .offset(x: -160)
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                }
                            }
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
                    justCompletedGroupIndex: store.justCompletedGroupIndex
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
                    onNext: { loadNextArtwork() },
                    onGallery: { withAnimation { showCompletion = false }; showGallery = true },
                    isTodayArtwork: store.currentArtworkIndex == Artwork.today().index,
                    skipReveal: skipReveal
                )
                .transition(.opacity)
            }

            // Header — above completion overlay so buttons stay tappable
            VStack {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                Spacer()
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
                skipReveal = true
                showCompletion = true
            }
            if !onboardingShown && store.phase != .complete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeIn(duration: 0.5)) { showOnboarding = true }
                }
            }
        }
        .onChange(of: store.currentArtworkIndex) { _, _ in
            // When switching artworks (e.g. "← Today"), if the new artwork
            // is already complete, show the overlay immediately.
            // onChange(of: store.phase) won't fire if phase stays .complete.
            if store.phase == .complete && !showCompletion {
                skipReveal = true
                withAnimation(.easeIn(duration: 0.8)) { showCompletion = true }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                store.persistNow()
            }
        }
        .onChange(of: store.filledElements.count) { _, count in
            // Peek tip: after 20 fills, if peek was never used
            if !peekTipShown && count == 20
                && store.peekUsesRemaining == ColoringStore.maxPeeksPerGame {
                withAnimation(.easeOut(duration: 0.4)) { showPeekTip = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeOut(duration: 0.3)) { showPeekTip = false }
                    peekTipShown = true
                }
            }
            // Find tip: after 40 fills, if find was never used
            if !findTipShown && count == 40
                && store.findUsesRemaining == ColoringStore.maxFindsPerGame {
                withAnimation(.easeOut(duration: 0.4)) { showFindTip = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeOut(duration: 0.3)) { showFindTip = false }
                    findTipShown = true
                }
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

    private var isOnTodayArtwork: Bool {
        store.currentArtworkIndex == Artwork.today().index
    }

    private var header: some View {
        HStack {
            if !isOnTodayArtwork {
                Button { store.loadArtwork(at: Artwork.today().index) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Today")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
                .accessibilityLabel("Return to today's artwork")
            }

            VStack(alignment: .leading, spacing: 2) {
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

                if isOnTodayArtwork {
                    Text(todayDateString)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer()

            if store.phase == .painting {
                Text(store.progressText)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .transition(.opacity)
            }

            if store.phase == .painting && store.peekUsesRemaining > 0 {
                Button {
                    dismissTips()
                    store.peek()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "eye")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(store.isPeeking ? 1.0 : 0.7))
                            .padding(10)
                            .background(Circle().fill(.white.opacity(store.isPeeking ? 0.2 : 0.08)))

                        Text("\(store.peekUsesRemaining)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(.white.opacity(0.25)))
                            .offset(x: 4, y: -4)
                    }
                }
                .buttonStyle(.plain)
                .disabled(store.isPeeking)
                .accessibilityLabel("Peek at finished artwork, \(store.peekUsesRemaining) uses remaining")
                .overlay(alignment: .bottom) {
                    if showPeekTip {
                        FeatureTip(text: "Peek at the finished art")
                            .offset(y: 44)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
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

    private func dismissTips() {
        withAnimation(.easeOut(duration: 0.2)) {
            showPeekTip = false
            showFindTip = false
        }
        peekTipShown = true
        findTipShown = true
    }

    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    private var hasUnfilledInSelectedGroup: Bool {
        guard store.selectedGroupIndex < store.document.groups.count else { return false }
        let group = store.document.groups[store.selectedGroupIndex]
        return group.elementIndices.contains(where: { !store.filledElements.contains($0) })
    }

    // MARK: - Next Artwork

    private func loadNextArtwork() {
        withAnimation { showCompletion = false }
        let isTodayArtwork = store.currentArtworkIndex == Artwork.today().index
        if isTodayArtwork {
            store.nextArtwork()
        } else {
            store.nextIncompleteArtwork()
        }
    }

    // MARK: - Completion Sequence

    private func beginCompletionSequence() {
        guard !showCompletion else { return }
        skipReveal = false  // fresh completion → animate the reveal

        // 0.0s — Canvas freezes (phase = .complete disables gestures).
        //        Numbers dissolve (CanvasView handles this, ~1s).

        // 0.8s — Slowly drift back to center (1.5s ease).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            store.triggerCompletionDrift()
        }

        // 2.0s — Overlay rises in (drift is mostly done, canvas is settled).
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.8)) { showCompletion = true }
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
                    isPeeking: false,
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

        if isOnTodayArtwork, let count = CompletionService.shared.globalCount, count > 0 {
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
        ("eye", "Peek ahead", "Curious what you're building? Tap the eye icon to peek at the finished artwork."),
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

// MARK: - Feature Tip

/// Small floating tooltip to nudge discovery of a feature.
private struct FeatureTip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(.white.opacity(0.15))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            )
            .fixedSize()
            .allowsHitTesting(false)
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

#Preview("Feature Tips") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 0) {
            // ── Simulated header (peek tip drops below eye icon) ──
            HStack {
                Text("Rocky Coastline")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Text("42 / 156")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                // Peek button with tip below
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "eye")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(10)
                        .background(Circle().fill(.white.opacity(0.08)))

                    Text("3")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(0.25)))
                        .offset(x: 4, y: -4)
                }
                .overlay(alignment: .bottom) {
                    FeatureTip(text: "Peek at the finished art")
                        .offset(y: 44)
                }

                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.03)))

                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // ── Simulated canvas area ──
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.03))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    // Find button with tip to the left
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "scope")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Circle().fill(.black.opacity(0.35)))
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                        Text("10")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(.red.opacity(0.85)))
                            .offset(x: 4, y: -4)
                    }
                    .overlay(alignment: .leading) {
                        FeatureTip(text: "Find hidden regions")
                            .offset(x: -160)
                    }
                    .padding(16)
                }
                .padding(.horizontal, 18)

            // ── Simulated palette ──
            HStack(spacing: 12) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text("\(i + 1)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }
    .preferredColorScheme(.dark)
}
