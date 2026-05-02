import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject var store: ColoringStore
    @State private var coloringActive = false
    @State private var showSettings = false
    @State private var countdownText = ""
    @State private var timerCancellable: (any Cancellable)?
    private let timer = Timer.publish(every: 60, on: .main, in: .common)

    private var todayIndex: Int { Artwork.today().index }
    private var todayArtwork: Artwork { Artwork.today().artwork }

    /// 7-day rolling backlog: today + 6 previous days.
    /// `recentDays` returns most-recent-first, so index 0 is today.
    private var recentDays: [(index: Int, artwork: Artwork)] {
        Artwork.recentDays(count: 7)
    }

    private var backlogDays: [(index: Int, artwork: Artwork)] {
        Array(recentDays.dropFirst())
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

                    if !countdownText.isEmpty {
                        Text(countdownText)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.top, 6)
                            .padding(.bottom, 4)
                    }

                    // MARK: - Backlog Strip
                    if !backlogDays.isEmpty {
                        backlogStrip
                            .padding(.top, 18)
                            .padding(.bottom, 32)
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("One Hue")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
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

    @State private var heroDocument: SVGDocument?

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
                        Text(hasProgress ? "Continue" : "Start Coloring")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.12)))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Today's artwork: \(todayArtwork.displayName)\(isCompleted ? ", completed" : "")")
        .task {
            if heroDocument == nil {
                heroDocument = await Task.detached(priority: .userInitiated) {
                    SVGDocumentCache.shared.document(for: todayArtwork)
                }.value
            }
        }
    }

    // MARK: - Backlog Strip

    /// The previous 6 days, shown as a quiet horizontal row of small thumbnails.
    /// Today is the hero above; this is the rolling window of recent days.
    private var backlogStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(backlogDays.enumerated()), id: \.element.artwork.id) { offset, item in
                        DayChip(
                            artwork: item.artwork,
                            index: item.index,
                            daysAgo: offset + 1
                        ) {
                            store.playBloop()
                            store.loadArtwork(at: item.index)
                            coloringActive = true
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
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

// MARK: - Day Chip

/// A small backlog cell — thumbnail + day label.
/// Shows completion state with a corner check; in-progress with a dim dot.
private struct DayChip: View {
    let artwork: Artwork
    let index: Int
    let daysAgo: Int
    let onTap: () -> Void

    @State private var document: SVGDocument?
    private let size: CGFloat = 92

    private var isCompleted: Bool { ColoringStore.isArtworkCompleted(artwork.id) }
    private var hasProgress: Bool {
        !(UserDefaults.standard.array(forKey: "onehue.svg.\(artwork.id)") as? [Int] ?? []).isEmpty
    }

    private var label: String {
        switch daysAgo {
        case 1: return "Yesterday"
        default: return "\(daysAgo) days ago"
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Color.appBackground
                    .frame(width: size, height: size)
                    .overlay {
                        if let doc = document {
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
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                    )
                    .overlay(alignment: .topTrailing) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                                .padding(5)
                        } else if hasProgress {
                            Circle()
                                .fill(.white.opacity(0.55))
                                .frame(width: 6, height: 6)
                                .padding(7)
                        }
                    }

                Text(label)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label): \(artwork.displayName)\(isCompleted ? ", completed" : "")")
        .task {
            if document == nil {
                document = await Task.detached(priority: .userInitiated) {
                    SVGDocumentCache.shared.document(for: artwork)
                }.value
            }
        }
    }
}

#Preview("Home") {
    HomeView(store: ColoringStore())
        .preferredColorScheme(.dark)
}
