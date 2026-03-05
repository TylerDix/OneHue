import SwiftUI
import Combine

@MainActor
final class DailyArtworkStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var artwork: DailyArtwork
    @Published var selectedColorIndex: Int = 0

    /// IDs of regions the user has filled
    @Published var filledRegionIDs: Set<Int> = [] {
        didSet { persistProgress() }
    }

    /// Debug day offset (0 = today)
    @Published var debugDayOffset: Int = 0 {
        didSet { reloadForCurrentDay() }
    }

    /// Drives the crossfade transition in TodayView during midnight handoff
    @Published var handoffPhase: HandoffPhase = .idle

    enum HandoffPhase: Equatable {
        case idle
        case fadingOut
        case fadingIn
    }

    // MARK: - Private

    /// The day string we currently display — used to detect date changes
    private var currentDayID: String

    /// Timer that checks for midnight crossing
    private var midnightTimer: AnyCancellable?

    /// Pre-cached artwork for tomorrow (loaded in background)
    private var tomorrowArtwork: DailyArtwork?

    // MARK: - Init

    init() {
        let dayID = Self.dayString(offsetDays: 0)
        let a = Self.loadArtwork(dayID: dayID)
        self.artwork = a
        self.currentDayID = dayID
        self.filledRegionIDs = Self.loadProgress(for: a.id)
        self.selectedColorIndex = 0

        startMidnightTimer()
        preCacheTomorrow()
    }

    // MARK: - Derived

    var isComplete: Bool { filledRegionIDs.count == artwork.regions.count }

    var progressFraction: Double {
        guard !artwork.regions.isEmpty else { return 0 }
        return Double(filledRegionIDs.count) / Double(artwork.regions.count)
    }

    var progressText: String { "\(filledRegionIDs.count) / \(artwork.regions.count)" }

    // MARK: - Actions

    /// Attempt to fill a region. Returns true if successful or already filled.
    func tryFill(regionID: Int) -> Bool {
        guard let region = artwork.regions.first(where: { $0.id == regionID }) else { return false }
        if filledRegionIDs.contains(regionID) { return true }
        guard selectedColorIndex == region.colorIndex else { return false }

        filledRegionIDs.insert(regionID)
        return true
    }

    func resetThisDayProgress() {
        filledRegionIDs = []
    }

    // MARK: - Scene Phase

    /// Call this from the view layer when the app returns to foreground.
    /// Catches cases where the user left the app before midnight and returns after.
    func onForeground() {
        checkForNewDay()
    }

    // MARK: - Debug Controls

    func debugPrevDay()     { debugDayOffset -= 1 }
    func debugNextDay()     { debugDayOffset += 1 }
    func debugBackToToday() { debugDayOffset = 0 }

    // MARK: - Midnight Handoff

    private func startMidnightTimer() {
        // Check every 30 seconds. Light — no work unless the date actually changed.
        midnightTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForNewDay()
            }
    }

    private func checkForNewDay() {
        let todayID = Self.dayString(offsetDays: debugDayOffset)
        guard todayID != currentDayID else { return }

        // Date has changed — begin handoff
        performHandoff(to: todayID)
    }

    private func performHandoff(to newDayID: String) {
        guard handoffPhase == .idle else { return }

        // Step 1: Fade out
        withAnimation(.easeOut(duration: 0.6)) {
            handoffPhase = .fadingOut
        }

        // Step 2: After fade out, swap the artwork
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self else { return }

            // Use pre-cached artwork if it matches, otherwise load fresh
            let newArtwork: DailyArtwork
            if let cached = self.tomorrowArtwork, cached.id == newDayID {
                newArtwork = cached
                self.tomorrowArtwork = nil
            } else {
                newArtwork = Self.loadArtwork(dayID: newDayID)
            }

            self.artwork = newArtwork
            self.currentDayID = newDayID
            self.selectedColorIndex = 0
            self.filledRegionIDs = Self.loadProgress(for: newArtwork.id)

            // Step 3: Fade in the new day
            withAnimation(.easeIn(duration: 0.6)) {
                self.handoffPhase = .fadingIn
            }

            // Step 4: Return to idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                self.handoffPhase = .idle
                self.preCacheTomorrow()
            }
        }
    }

    // MARK: - Pre-caching

    /// Load tomorrow's artwork into memory so the midnight transition is instant.
    private func preCacheTomorrow() {
        let tomorrowID = Self.dayString(offsetDays: debugDayOffset + 1)
        // Load on a background-friendly path (the load itself is synchronous bundle access,
        // but we keep it off the hot path)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.tomorrowArtwork = Self.loadArtwork(dayID: tomorrowID)
        }
    }

    // MARK: - Reload (debug)

    private func reloadForCurrentDay() {
        let dayID = Self.dayString(offsetDays: debugDayOffset)
        let newArtwork = Self.loadArtwork(dayID: dayID)
        artwork = newArtwork
        currentDayID = dayID
        selectedColorIndex = 0
        filledRegionIDs = Self.loadProgress(for: newArtwork.id)
        tomorrowArtwork = nil
        preCacheTomorrow()
    }

    // MARK: - Loading

    private static func loadArtwork(dayID: String) -> DailyArtwork {
        let filename = "daily_\(dayID)"

        // 1. Try JSON manifest (production path)
        if let a = try? DailyArtworkDecoder.loadBundledJSON(named: filename) {
            return a
        }

        // 2. Try SVG file directly
        if let a = try? SVGDocumentParser.parse(
            svgNamed: filename,
            id: dayID,
            title: "Today",
            subject: "",
            completionMessage: "Nice. A little calmer now."
        ) {
            return a
        }

        // 3. Fallback: mock artwork for development
        return makeMockArtwork(dayID: dayID)
    }

    // MARK: - Persistence

    private func persistProgress() {
        let key = Self.progressKey(for: artwork.id)
        UserDefaults.standard.set(Array(filledRegionIDs), forKey: key)
    }

    private static func loadProgress(for dayID: String) -> Set<Int> {
        let key = progressKey(for: dayID)
        let arr = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        return Set(arr)
    }

    private static func progressKey(for dayID: String) -> String {
        "onehue.progress.\(dayID)"
    }

    // MARK: - Date Helpers

    private static func dayString(offsetDays: Int) -> String {
        let cal = Calendar(identifier: .gregorian)
        let base = cal.startOfDay(for: Date())
        let date = cal.date(byAdding: .day, value: offsetDays, to: base) ?? base
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Mock Fallback

    private static func makeMockArtwork(dayID: String) -> DailyArtwork {
        let palette: [Color] = [
            Color(hex: "#FF6B9D"),  // 0: Rose Pink
            Color(hex: "#FF8C42"),  // 1: Warm Orange
            Color(hex: "#FFD166"),  // 2: Sunflower
            Color(hex: "#06D6A0"),  // 3: Mint Green
            Color(hex: "#118AB2"),  // 4: Ocean Blue
            Color(hex: "#073B4C"),  // 5: Deep Navy
            Color(hex: "#9B5DE5"),  // 6: Soft Purple
            Color(hex: "#F15BB5"),  // 7: Hot Pink
        ]

        var regions: [Region] = []
        var id = 0

        func add(_ number: Int, _ colorIndex: Int, _ path: Path) {
            regions.append(Region(id: id, number: number, colorIndex: colorIndex, path: path))
            id += 1
        }

        // Outer ring segments (normalized 0...1)
        add(1, 0, Path { p in
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4,
                     startAngle: .degrees(-90), endAngle: .degrees(-30), clockwise: false)
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.35,
                     startAngle: .degrees(-30), endAngle: .degrees(-90), clockwise: true)
            p.closeSubpath()
        })
        add(2, 1, Path { p in
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4,
                     startAngle: .degrees(-30), endAngle: .degrees(30), clockwise: false)
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.35,
                     startAngle: .degrees(30), endAngle: .degrees(-30), clockwise: true)
            p.closeSubpath()
        })
        add(3, 2, Path { p in
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4,
                     startAngle: .degrees(30), endAngle: .degrees(90), clockwise: false)
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.35,
                     startAngle: .degrees(90), endAngle: .degrees(30), clockwise: true)
            p.closeSubpath()
        })
        add(4, 3, Path { p in
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4,
                     startAngle: .degrees(90), endAngle: .degrees(150), clockwise: false)
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.35,
                     startAngle: .degrees(150), endAngle: .degrees(90), clockwise: true)
            p.closeSubpath()
        })
        add(5, 4, Path { p in
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4,
                     startAngle: .degrees(150), endAngle: .degrees(210), clockwise: false)
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.35,
                     startAngle: .degrees(210), endAngle: .degrees(150), clockwise: true)
            p.closeSubpath()
        })
        add(6, 5, Path { p in
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.4,
                     startAngle: .degrees(210), endAngle: .degrees(270), clockwise: false)
            p.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.35,
                     startAngle: .degrees(270), endAngle: .degrees(210), clockwise: true)
            p.closeSubpath()
        })

        add(7, 6, Path(CGRect(x: 0.485, y: 0.1, width: 0.03, height: 0.4)))
        add(7, 6, Path(CGRect(x: 0.485, y: 0.5, width: 0.03, height: 0.4)))
        add(8, 7, Path { p in
            p.move(to: CGPoint(x: 0.5, y: 0.5))
            p.addLine(to: CGPoint(x: 0.28, y: 0.72))
            p.addLine(to: CGPoint(x: 0.30, y: 0.74))
            p.addLine(to: CGPoint(x: 0.52, y: 0.52))
            p.closeSubpath()
        })
        add(8, 7, Path { p in
            p.move(to: CGPoint(x: 0.5, y: 0.5))
            p.addLine(to: CGPoint(x: 0.72, y: 0.72))
            p.addLine(to: CGPoint(x: 0.70, y: 0.74))
            p.addLine(to: CGPoint(x: 0.48, y: 0.52))
            p.closeSubpath()
        })

        return DailyArtwork(
            id: dayID,
            title: "Peace",
            subject: "peace symbol",
            completionMessage: "Today, [count] people traced the oldest wish in the world back into color. It still means what it always meant.",
            palette: palette,
            regions: regions,
            viewBoxWidth: 1,
            viewBoxHeight: 1
        )
    }
}
