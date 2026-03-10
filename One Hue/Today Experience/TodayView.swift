import SwiftUI

struct TodayView: View {
    @StateObject private var store = ColoringStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSettings    = false
    @State private var showCompletion  = false
    @State private var showShareSheet  = false
    @State private var showGallery     = false
    @State private var shareImage: UIImage? = nil

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
                    artworkID: store.currentArtwork.id,
                    completionService: CompletionService.shared,
                    onShare: { shareCompletedArtwork() },
                    onNext: { loadNextArtwork() }
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            if store.phase == .complete {
                showCompletion = true
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

            Button { showGallery = true } label: {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)

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

// MARK: - Previews

#Preview("Pristine") {
    TodayView().preferredColorScheme(.dark)
}
