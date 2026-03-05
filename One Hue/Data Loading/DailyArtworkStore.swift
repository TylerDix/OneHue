import SwiftUI
import Combine

@MainActor
final class DailyArtworkStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var artwork: DailyArtwork
    @Published var selectedColorIndex: Int = 0

    /// IDs of regions the user has filled
    @Published var filledRegionIDs: Set<Int> = [] {
        didSet {
            persistProgress()
            checkCompletion()
        }
    }

    /// Debug day offset (0 = today)
    @Published var debugDayOffset: Int = 0 {
        didSet { reloadForCurrentDay() }
    }

    /// Drives the crossfade transition in TodayView during midnight handoff
    @Published var handoffPhase: HandoffPhase = .idle

    /// Live global completion count from Supabase
    @Published var globalCount: Int = 0

    enum HandoffPhase: Equatable {
        case idle
        case fadingOut
        case fadingIn
    }

    // MARK: - Private

    private var currentDayID: String
    private var midnightTimer: AnyCancellable?
    private var tomorrowArtwork: DailyArtwork?
    private var countPollTask: Task<Void, Never>?

    /// Tracks whether we already reported completion for the current day
    /// (prevents double-increment if the user re-opens the completed image)
    private var didReportCompletion: Bool = false

    // MARK: - Init

    init() {
        let dayID = Self.dayString(offsetDays: 0)
        let a = Self.loadArtwork(dayID: dayID)
        self.artwork = a
        self.currentDayID = dayID
        self.filledRegionIDs = Self.loadProgress(for: a.id)
        self.selectedColorIndex = 0
        self.didReportCompletion = Self.loadDidReport(for: dayID)

        startMidnightTimer()
        preCacheTomorrow()

        // If already complete from a previous session, fetch the current count
        if isComplete {
            Task { await fetchCurrentCount() }
        }
    }

    // MARK: - Derived

    var isComplete: Bool { filledRegionIDs.count == artwork.regions.count }

    var progressFraction: Double {
        guard !artwork.regions.isEmpty else { return 0 }
        return Double(filledRegionIDs.count) / Double(artwork.regions.count)
    }

    var progressText: String { "\(filledRegionIDs.count) / \(artwork.regions.count)" }

    // MARK: - Actions

    func tryFill(regionID: Int) -> Bool {
        guard let region = artwork.regions.first(where: { $0.id == regionID }) else { return false }
        if filledRegionIDs.contains(regionID) { return true }
        guard selectedColorIndex == region.colorIndex else { return false }

        filledRegionIDs.insert(regionID)
        return true
    }

    func resetThisDayProgress() {
        filledRegionIDs = []
        didReportCompletion = false
        globalCount = 0
        stopPolling()
        Self.clearDidReport(for: currentDayID)
    }

    // MARK: - Completion + Counter

    private func checkCompletion() {
        guard isComplete, !didReportCompletion else { return }
        didReportCompletion = true
        Self.saveDidReport(for: currentDayID)

        // Increment the global counter and start polling for live updates
        Task {
            let newCount = await OneHueAPI.incrementCount(for: currentDayID)
            globalCount = newCount
            startPolling()
        }
    }

    private func fetchCurrentCount() async {
        let count = await OneHueAPI.fetchCount(for: currentDayID)
        globalCount = count
    }

    private func startPolling() {
        stopPolling()
        countPollTask = OneHueAPI.pollCount(for: currentDayID, interval: 15) { [weak self] count in
            self?.globalCount = count
        }
    }

    private func stopPolling() {
        countPollTask?.cancel()
        countPollTask = nil
    }

    // MARK: - Scene Phase

    func onForeground() {
        checkForNewDay()
        // Refresh count if on the completion screen
        if isComplete {
            Task { await fetchCurrentCount() }
        }
    }

    // MARK: - Debug Controls

    func debugPrevDay()     { debugDayOffset -= 1 }
    func debugNextDay()     { debugDayOffset += 1 }
    func debugBackToToday() { debugDayOffset = 0 }

    // MARK: - Midnight Handoff

    private func startMidnightTimer() {
        midnightTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForNewDay()
            }
    }

    private func checkForNewDay() {
        let todayID = Self.dayString(offsetDays: debugDayOffset)
        guard todayID != currentDayID else { return }
        performHandoff(to: todayID)
    }

    private func performHandoff(to newDayID: String) {
        guard handoffPhase == .idle else { return }

        stopPolling()

        withAnimation(.easeOut(duration: 0.6)) {
            handoffPhase = .fadingOut
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self else { return }

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
            self.didReportCompletion = Self.loadDidReport(for: newDayID)
            self.globalCount = 0

            withAnimation(.easeIn(duration: 0.6)) {
                self.handoffPhase = .fadingIn
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                self.handoffPhase = .idle
                self.preCacheTomorrow()
            }
        }
    }

    // MARK: - Pre-caching

    private func preCacheTomorrow() {
        let tomorrowID = Self.dayString(offsetDays: debugDayOffset + 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.tomorrowArtwork = Self.loadArtwork(dayID: tomorrowID)
        }
    }

    // MARK: - Reload (debug)

    private func reloadForCurrentDay() {
        stopPolling()
        let dayID = Self.dayString(offsetDays: debugDayOffset)
        let newArtwork = Self.loadArtwork(dayID: dayID)
        artwork = newArtwork
        currentDayID = dayID
        selectedColorIndex = 0
        filledRegionIDs = Self.loadProgress(for: newArtwork.id)
        didReportCompletion = Self.loadDidReport(for: dayID)
        globalCount = 0
        tomorrowArtwork = nil
        preCacheTomorrow()
    }

    // MARK: - Loading

    private static func loadArtwork(dayID: String) -> DailyArtwork {
        let filename = "daily_\(dayID)"

        if let a = try? DailyArtworkDecoder.loadBundledJSON(named: filename) {
            return a
        }

        if let a = try? SVGDocumentParser.parse(
            svgNamed: filename,
            id: dayID,
            title: "Today",
            subject: "",
            completionMessage: "Nice. A little calmer now."
        ) {
            return a
        }

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

    // Track whether we already incremented the counter for this day
    private static func saveDidReport(for dayID: String) {
        UserDefaults.standard.set(true, forKey: "onehue.reported.\(dayID)")
    }
    private static func loadDidReport(for dayID: String) -> Bool {
        UserDefaults.standard.bool(forKey: "onehue.reported.\(dayID)")
    }
    private static func clearDidReport(for dayID: String) {
        UserDefaults.standard.removeObject(forKey: "onehue.reported.\(dayID)")
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
            Color(hex: "#FF6B9D"),
            Color(hex: "#FF8C42"),
            Color(hex: "#FFD166"),
            Color(hex: "#06D6A0"),
            Color(hex: "#118AB2"),
            Color(hex: "#073B4C"),
            Color(hex: "#9B5DE5"),
            Color(hex: "#F15BB5"),
        ]

        var regions: [Region] = []
        var id = 0

        func add(_ number: Int, _ colorIndex: Int, _ path: Path) {
            regions.append(Region(id: id, number: number, colorIndex: colorIndex, path: path))
            id += 1
        }

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
