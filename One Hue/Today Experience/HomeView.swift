import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject var store: ColoringStore
    @State private var coloringActive = false
    @State private var filter: GalleryFilter = .all
    @State private var showSettings = false
    @State private var countdownText = ""
    @State private var timerCancellable: (any Cancellable)?
    @State private var heroDocument: SVGDocument?
    private let timer = Timer.publish(every: 60, on: .main, in: .common)

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 14)
    ]

    init(store: ColoringStore) {
        self.store = store
        // Synchronously parse today's SVG so the hero card is never blank on cold launch.
        // One-time cost at app startup; subsequent navigations reuse the cached doc.
        let today = Artwork.today().artwork
        let doc = SVGDocumentCache.shared.peekDocument(for: today)
            ?? SVGDocumentCache.shared.document(for: today)
        self._heroDocument = State(initialValue: doc)
    }

    private var todayIndex: Int { Artwork.today().index }
    private var todayArtwork: Artwork { Artwork.today().artwork }

    private var sections: [GalleryMonthSection] {
        GalleryMonthSection.buildSections(filter: filter)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Hero Card
                    heroCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    // MARK: - Filter
                    HStack(spacing: 8) {
                        ForEach(GalleryFilter.allCases, id: \.self) { f in
                            let isSelected = filter == f
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    filter = f
                                }
                            } label: {
                                Text(f.rawValue)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.55))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(.white.opacity(isSelected ? 0.12 : 0))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if !countdownText.isEmpty {
                        Text(countdownText)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.top, 2)
                            .padding(.bottom, 4)
                    }

                    // MARK: - Grid
                    if sections.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: filter == .completed ? "paintbrush" : "checkmark.seal")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(.white.opacity(0.3))
                            Text(filter == .completed ? "Nothing finished yet — take your time." : "Every page colored. Well done.")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(sections) { section in
                                Text(section.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 24)
                                    .padding(.bottom, 8)

                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(section.artworks, id: \.artwork.id) { item in
                                        GalleryCell(
                                            artwork: item.artwork,
                                            index: item.index,
                                            isCurrent: item.index == store.currentArtworkIndex,
                                            isToday: item.index == todayIndex
                                        ) {
                                            store.playBloop()
                                            store.loadArtwork(at: item.index)
                                            coloringActive = true
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.appBackground)
            #if !os(macOS)
            .toolbarBackground(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(isPresented: $coloringActive) {
                TodayView(store: store, coloringActive: $coloringActive)
                    #if !os(macOS)
                    .navigationBarHidden(true)
                    #endif
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
                .presentationDetents([.large])
        }
        .onAppear {
            updateCountdown()
            // Defer preload so gallery animates in first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SVGDocumentCache.shared.preloadAll()
            }
            timerCancellable = timer.connect()
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
        .onReceive(timer) { _ in
            updateCountdown()
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let isCompleted = ColoringStore.isArtworkCompleted(todayArtwork.id)

        return Button {
            store.playBloop()
            store.loadArtwork(at: todayIndex)
            coloringActive = true
        } label: {
            VStack(spacing: 0) {
                // Thumbnail
                Color.appBackground
                    .aspectRatio(heroDocument?.aspectRatio ?? (1200.0 / 1200.0), contentMode: .fit)
                    .overlay {
                        if let doc = heroDocument {
                            SVGCanvasRenderer(
                                document: doc,
                                filledElements: isCompleted ? Set(0..<doc.totalElements) : [],
                                selectedGroupIndex: nil,
                                showNumbers: false,
                                isPeeking: false,
                                zoomLevel: 1.0,
                                activeAnimations: [],
                                flashTick: 0,
                                pulsePhase: 0,
                                strokeDissolve: 0
                            )
                            .drawingGroup()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Text("Today")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(.white.opacity(0.25))
                            )
                            .padding(10)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                                .padding(10)
                        }
                    }

                // Info row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(todayArtwork.displayName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(todayDateString)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    if !isCompleted {
                        let hasProgress = !(UserDefaults.standard.array(forKey: "onehue.svg.\(todayArtwork.id)") as? [Int] ?? []).isEmpty
                        HStack(spacing: 4) {
                            Text(hasProgress ? "Continue" : "Start")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Today's artwork: \(todayArtwork.displayName)\(isCompleted ? ", completed" : "")")
    }

    // MARK: - Helpers

    private static let utcDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private var todayDateString: String {
        Self.utcDateFormatter.string(from: Date())
    }

    private func updateCountdown() {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let now = Date()
        guard let midnight = utcCal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else {
            countdownText = ""
            return
        }
        let diff = utcCal.dateComponents([.hour, .minute], from: now, to: midnight)
        let h = diff.hour ?? 0
        let m = diff.minute ?? 0
        if h > 0 {
            countdownText = "Next artwork in \(h)h \(m)m"
        } else {
            countdownText = "Next artwork in \(m)m"
        }
    }
}

#Preview("Home") {
    HomeView(store: ColoringStore())
        .preferredColorScheme(.dark)
}
