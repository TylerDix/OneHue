import SwiftUI

struct TodayView: View {
    @ObservedObject var store: ColoringStore
    @Binding var coloringActive: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var showSettings    = false
    @State private var showCompletion  = false
    @State private var skipReveal      = false
    @State private var showShareSheet  = false
    @State private var shareImage: PlatformImage? = nil
    @AppStorage("onehue.onboardingShown") private var onboardingShown = false
    @State private var showOnboarding = false

    // Feature tooltips — shown once ever if the user hasn't discovered the feature
    @AppStorage("onehue.tip.peek") private var peekTipShown = false
    @AppStorage("onehue.tip.find") private var findTipShown = false
    @AppStorage("onehue.tip.palette") private var paletteTipShown = false
    @State private var showPeekTip = false
    @State private var showFindTip = false
    @State private var showPaletteTip = false

    // "Stuck" hint — nudges the scope button when few pieces remain and user is idle
    @State private var showStuckHint = false
    @State private var stuckTimer: Timer?

    // Completion reveal
    @State private var showReveal = false
    @State private var lastTapNormalized: CGPoint? = nil

    #if DEBUG
    // Debug overlay — toggled via long-press on title
    @State private var showDebugOverlay = false
    #endif

    // TesterPanel removed — debug tools consolidated into Settings (5-tap tagline)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header spacer — reserves height in VStack for the overlaid header.
                // Black background matches the app chrome.
                Color.black
                    .frame(height: 44)
                    .padding(.top, 4)

                // Canvas
                CanvasView(store: store, lastTapNormalized: $lastTapNormalized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        if store.loadFailed {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("Artwork couldn't load")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if store.phase == .painting && hasUnfilledInSelectedGroup {
                            let exhausted = store.findUsesRemaining <= 0
                            Button {
                                guard !exhausted else { return }
                                dismissTips(); showStuckHint = false; store.findNextUnfilled()
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "scope")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white.opacity(exhausted ? 0.3 : 1.0))
                                        .padding(12)
                                        .background(Circle().fill(.black.opacity(exhausted ? 0.15 : 0.35)))
                                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                                    if store.findUsesRemaining > 0, store.findUsesRemaining <= 3 {
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
                            .accessibilityLabel(exhausted ? "Find uses exhausted" : "Find next unfilled region, \(store.findUsesRemaining) uses remaining")
                            .overlay(alignment: .leading) {
                                if showStuckHint {
                                    FeatureTip(text: "Stuck? Tap to find it")
                                        .offset(x: -170)
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                } else if showFindTip {
                                    FeatureTip(text: "Find hidden regions")
                                        .offset(x: -160)
                                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                                }
                            }
                            .padding(16)
                            .transition(.opacity)
                        }
                    }
                    .overlay(alignment: .bottomLeading) {
                        if store.phase == .painting {
                            VStack(alignment: .leading, spacing: 8) {
                                #if DEBUG
                                // Debug overlay
                                if showDebugOverlay {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Taps: \(store.tapCount)")
                                        Text("Grabbed: \(store.autoGrabbedCount)")
                                        Text("Elements: \(store.document.totalElements)")
                                        Text("Grab: \(store.debugDisableTinyGrab ? "OFF" : "ON")")
                                            .foregroundStyle(store.debugDisableTinyGrab ? .red : .green)
                                    }
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.6)))
                                    .onTapGesture {
                                        store.debugDisableTinyGrab.toggle()
                                    }
                                    .transition(.opacity)
                                }
                                #endif

                                // Zoom-to-fit button (disabled)
//                                Button {
//                                    store.resetZoomTrigger.toggle()
//                                } label: {
//                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
//                                        .font(.system(size: 18, weight: .bold))
//                                        .foregroundStyle(.white)
//                                        .padding(14)
//                                        .background(Circle().fill(.black.opacity(0.35)))
//                                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
//                                }
//                                .buttonStyle(.plain)
//                                .accessibilityLabel("Zoom to fit")
                            }
                            .padding(16)
                        }
                    }
                    .accessibilityLabel("Coloring canvas, \(store.document.title)")
                    .accessibilityHint("Tap colored regions to fill them")

                // Palette bar — slides off bottom on completion
                if !showCompletion {
                    ZStack(alignment: .top) {
                        PaletteView(
                            groups: store.document.groups,
                            selectedIndex: $store.selectedGroupIndex,
                            filledElements: store.filledElements,
                            justCompletedGroupIndex: store.justCompletedGroupIndex
                        )

                        if showPaletteTip {
                            FeatureTip(text: "Tap a color to highlight its pieces")
                                .offset(y: -28)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: store.phase) { _, phase in
                withAnimation {
                    if phase == .complete {
                        stuckTimer?.invalidate(); stuckTimer = nil
                        showStuckHint = false
                        beginCompletionSequence()
                    }
                    if phase == .painting { resetCompletionSequence() }
                }
            }

            // Radial reveal — expands from last tap point on completion
            RadialRevealView(
                origin: lastTapNormalized,
                isActive: $showReveal
            )
            .allowsHitTesting(false)
            .ignoresSafeArea()

            // Completion overlay — the app's resting state until midnight
            if showCompletion {
                CompletionOverlayView(
                    message: store.document.completionMessage,
                    artworkID: store.currentArtwork.id,
                    completionService: CompletionService.shared,
                    onNext: { loadNextArtwork() },
                    onGallery: { showCompletion = false; coloringActive = false },
                    onShare: { shareCompletedArtwork() },
                    isTodayArtwork: store.currentArtworkIndex == Artwork.today().index,
                    skipReveal: skipReveal
                )
                .transition(.opacity)
            }

            // Header — pinned to top, above completion overlay so buttons stay tappable
            VStack(spacing: 0) {
                header
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .background(Color.black)

                // (tester panel is a sheet — no inline bar needed)

                Color.clear
                    .allowsHitTesting(false)
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
                dismissAllHints()
                withAnimation(.easeOut(duration: 0.4)) { showPeekTip = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeOut(duration: 0.3)) { showPeekTip = false }
                    peekTipShown = true
                }
            }
            // Find tip: after 40 fills, if find was never used
            else if !findTipShown && count == 40
                && store.findUsesRemaining == ColoringStore.maxFindsPerGame {
                dismissAllHints()
                withAnimation(.easeOut(duration: 0.4)) { showFindTip = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeOut(duration: 0.3)) { showFindTip = false }
                    findTipShown = true
                }
            }
            // Stuck hint: reset on any fill, re-arm if few pieces remain
            withAnimation(.easeOut(duration: 0.2)) { showStuckHint = false }
            armStuckTimer()
        }
        .onChange(of: store.justCompletedGroupIndex) { _, newVal in
            // Palette tip: after first group completion, hint that tapping a color highlights
            if !paletteTipShown, newVal != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    guard !paletteTipShown else { return }
                    dismissAllHints()
                    withAnimation(.easeOut(duration: 0.4)) { showPaletteTip = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation(.easeOut(duration: 0.3)) { showPaletteTip = false }
                        paletteTipShown = true
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
                .presentationDetents([.large])
        }
        // Gallery is now the home screen — no sheet needed
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image, "One Hue — \(store.currentArtwork.displayName)"])
            }
        }
        // TesterPanel sheet removed — debug tools now in Settings
    }

    // MARK: - Header

    private var isOnTodayArtwork: Bool {
        store.currentArtworkIndex == Artwork.today().index
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(store.document.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(-1)
                        #if DEBUG
                        // DEBUG: 5-tap title to reset artwork, 3-tap to preview completion
                        .onTapGesture(count: 5) {
                            showCompletion = false
                            showReveal = false
                            skipReveal = false
                            store.resetProgress()
                        }
                        .onTapGesture(count: 3) {
                            showReveal = false
                            DispatchQueue.main.async { showReveal = true }
                            skipReveal = true
                            withAnimation(.easeOut(duration: 0.5)) { showCompletion = true }
                        }
                        // DEBUG: long-press title to toggle tap counter overlay
                        .onLongPressGesture {
                            withAnimation { showDebugOverlay.toggle() }
                        }
                        #endif

                    if store.phase == .complete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .transition(.opacity)
                    }
                }

                if isOnTodayArtwork {
                    HStack(spacing: 6) {
                        Text(todayDateString)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))

                        let streak = ColoringStore.currentStreak
                        if streak >= 2 {
                            Text("Day \(streak)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            // Peek button (disabled)
//            if store.phase == .painting && store.peekUsesRemaining > 0 {
//                Button {
//                    dismissTips()
//                    store.peek()
//                } label: {
//                    ZStack(alignment: .topTrailing) {
//                        Image(systemName: "eye")
//                            .font(.system(size: 15, weight: .semibold))
//                            .foregroundStyle(.white.opacity(store.isPeeking ? 1.0 : 0.9))
//                            .padding(10)
//                            .background(Circle().fill(.black.opacity(store.isPeeking ? 0.55 : 0.35)))
//                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
//
//                        Text("\(store.peekUsesRemaining)")
//                            .font(.system(size: 11, weight: .bold, design: .rounded))
//                            .foregroundStyle(.white)
//                            .frame(width: 18, height: 18)
//                            .background(Circle().fill(.white.opacity(0.25)))
//                            .offset(x: 4, y: -4)
//                    }
//                }
//                .buttonStyle(.plain)
//                .disabled(store.isPeeking)
//                .accessibilityLabel("Peek at finished artwork, \(store.peekUsesRemaining) uses remaining")
//                .overlay(alignment: .bottom) {
//                    if showPeekTip {
//                        FeatureTip(text: "Peek at the finished art")
//                            .offset(y: 44)
//                            .transition(.opacity.combined(with: .move(edge: .top)))
//                    }
//                }
//                .transition(.opacity)
//            }

            // Progress ring — percentage complete
            if store.phase == .painting && store.filledElements.count > 0 {
                let pct = store.progressFraction
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(width: 32, height: 32)
                .transition(.opacity)
            }

            Button { coloringActive = false } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(10)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Gallery")

            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(10)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Helpers

    /// Dismiss all tips permanently (user interacted, so they don't need them)
    private func dismissTips() {
        withAnimation(.easeOut(duration: 0.2)) {
            showPeekTip = false
            showFindTip = false
            showPaletteTip = false
        }
        peekTipShown = true
        findTipShown = true
        paletteTipShown = true
    }

    /// Dismiss all visible hints/tips without marking them as permanently shown.
    /// Used before showing a new tip so only one is visible at a time.
    private func dismissAllHints() {
        withAnimation(.easeOut(duration: 0.2)) {
            showPeekTip = false
            showFindTip = false
            showPaletteTip = false
            showStuckHint = false
        }
        stuckTimer?.invalidate()
        stuckTimer = nil
    }

    private static let utcDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private var todayDateString: String {
        Self.utcDateFormatter.string(from: Date())
    }

    /// Arms a timer that shows the "stuck" tooltip on the scope button after
    /// 8 seconds of inactivity, but only when few pieces remain in the artwork.
    private func armStuckTimer() {
        stuckTimer?.invalidate()
        stuckTimer = nil
        guard store.phase == .painting,
              store.findUsesRemaining > 0 else { return }
        let groupRemaining: Int
        if let selIdx = store.selectedGroupIndex, selIdx < store.document.groups.count {
            let group = store.document.groups[selIdx]
            groupRemaining = group.elementIndices.filter { !store.filledElements.contains($0) }.count
        } else {
            groupRemaining = store.globalRemaining
        }
        guard groupRemaining > 0, groupRemaining <= 5 else { return }
        stuckTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { _ in
            Task { @MainActor in
                guard store.phase == .painting, store.globalRemaining > 0 else { return }
                // Don't show stuck hint if another tip is visible
                guard !showPeekTip, !showFindTip, !showPaletteTip else { return }
                withAnimation(.easeOut(duration: 0.4)) { showStuckHint = true }
                // Auto-dismiss after 6s if not acted on
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    withAnimation(.easeOut(duration: 0.3)) { showStuckHint = false }
                }
            }
        }
    }

    private var hasUnfilledInSelectedGroup: Bool {
        guard let selIdx = store.selectedGroupIndex, selIdx < store.document.groups.count else { return false }
        let group = store.document.groups[selIdx]
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

        if skipReveal {
            // Returning to an already-completed artwork — show overlay immediately
            withAnimation(.easeOut(duration: 0.3)) { showCompletion = true }
            return
        }

        // Fresh completion — full celebratory reveal

        // 0.0s — Canvas freezes (phase = .complete disables gestures).
        //        Numbers dissolve (CanvasView handles this, ~1s).
        //        Radial reveal expands from last tap point.
        showReveal = true

        // 0.8s — Slowly drift back to center (1.5s ease).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            store.triggerCompletionDrift()
        }

        // 2.5s — Overlay rises in (glow ring finished, canvas is settled).
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.8)) { showCompletion = true }
        }
    }

    private func resetCompletionSequence() {
        showCompletion = false
        showReveal = false
        stuckTimer?.invalidate()
        stuckTimer = nil
        showStuckHint = false
    }

    // MARK: - Share

    private func shareCompletedArtwork() {
        let allFilled = Set(0..<store.document.elements.count)
        let canvasWidth: CGFloat = 1024
        let canvasHeight = canvasWidth / store.document.aspectRatio
        let message = store.document.completionMessage
        let title = store.currentArtwork.displayName

        let renderer = ImageRenderer(content:
            ZStack {
                // Completed artwork
                SVGCanvasRenderer(
                    document: store.document,
                    filledElements: allFilled,
                    selectedGroupIndex: nil,
                    showNumbers: false,
                    isPeeking: false,
                    zoomLevel: 1.0,
                    activeAnimations: [],
                    flashTick: 0,
                    pulsePhase: 0,
                    strokeDissolve: 0
                )
                .frame(width: canvasWidth, height: canvasHeight)

                // Dimmed overlay
                Color.black.opacity(0.45)

                // Quote card + branding
                VStack(spacing: 20) {
                    Spacer()

                    // Quote card
                    VStack(spacing: 12) {
                        Text(CompletionOverlayView.preventOrphan(message))
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .kerning(-0.2)

                        Text("— \(title)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
                    .frame(maxWidth: 400)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.black.opacity(0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                            )
                    )

                    Spacer()

                    // App branding at bottom
                    Text("One Hue")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .background(Color.black)
        )
        renderer.scale = 2.0
        #if canImport(UIKit)
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
        #elseif canImport(AppKit)
        if let cgImage = renderer.cgImage {
            shareImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            showShareSheet = true
        }
        #endif
    }

    private var shareCaption: String {
        let title = store.currentArtwork.displayName

        let date = Self.utcDateFormatter.string(from: Date())

        if isOnTodayArtwork, let count = CompletionService.shared.globalCount, count > 0 {
            let formatted = count.formatted(.number)
            return "\(title) — \(date) — Colored by \(formatted) people"
        }
        return "\(title) — \(date)"
    }
}

// MARK: - Share Sheet

#if canImport(UIKit)
import UIKit

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#elseif canImport(AppKit)
import AppKit

private struct ShareSheet: NSViewRepresentable {
    let items: [Any]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Present sharing picker once the view is in the window
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

// MARK: - Onboarding Overlay

private struct OnboardingOverlay: View {
    let onDismiss: () -> Void
    @State private var step = 0

    private let steps: [(icon: String, title: String, body: String)] = [
        ("paintbrush.pointed", "Tap to fill", "Each region has a number. Select a color from the palette, then tap matching regions to fill them."),
        ("scope", "Find regions", "Lost a region? Tap the scope button to zoom to the next unfilled area for your selected color."),
        // ("eye", "Peek ahead", "Curious what you're building? Tap the eye icon to peek at the finished artwork."),
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
                Capsule().fill(.black.opacity(0.35))
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            )
            .fixedSize()
            .allowsHitTesting(false)
    }
}

// MARK: - Previews

#Preview("Pristine") {
    TodayView(store: ColoringStore(), coloringActive: .constant(true)).preferredColorScheme(.dark)
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
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(10)
                        .background(Circle().fill(.black.opacity(0.35)))
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

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
