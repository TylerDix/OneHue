import SwiftUI
import Combine

@MainActor
final class DailyArtworkStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var artwork: DailyArtwork
    @Published var selectedColorIndex: Int = 0

    /// Filled region IDs for the currently-loaded artwork/day
    @Published var filledRegionIDs: Set<Int> = [] {
        didSet { persistProgress() }
    }

    /// Debug day offset (0 = today). Changing this reloads artwork + progress.
    @Published var debugDayOffset: Int = 0 {
        didSet { reloadForCurrentDay() }
    }

    // MARK: - Init

    init() {
        let dayID = Self.dayString(offsetDays: 0)
        let a = Self.loadArtwork(dayID: dayID)

        self.artwork = a
        self.filledRegionIDs = Self.loadProgress(for: a.id)
        self.selectedColorIndex = 0
    }

    // MARK: - Derived

    var isComplete: Bool { filledRegionIDs.count == artwork.regions.count }

    var progressText: String { "\(filledRegionIDs.count) / \(artwork.regions.count)" }

    // MARK: - Actions

    /// Returns true if the fill succeeds OR the region was already filled.
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

    // MARK: - Debug Controls

    func debugPrevDay() { debugDayOffset -= 1 }
    func debugNextDay() { debugDayOffset += 1 }
    func debugBackToToday() { debugDayOffset = 0 }

    // MARK: - Reload

    private func reloadForCurrentDay() {
        let dayID = Self.dayString(offsetDays: debugDayOffset)

        // Load artwork first
        let newArtwork = Self.loadArtwork(dayID: dayID)

        // Apply state updates (order matters: artwork first, then dependent state)
        artwork = newArtwork
        selectedColorIndex = 0

        // Load progress for that day/artwork id
        filledRegionIDs = Self.loadProgress(for: newArtwork.id)
    }

    private static func loadArtwork(dayID: String) -> DailyArtwork {
        let filename = "daily_\(dayID)"
        if let a = try? DailyArtworkDecoder.loadBundledJSON(named: filename) {
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

    // MARK: - Date helpers

    private static func dayString(offsetDays: Int) -> String {
        let cal = Calendar(identifier: .gregorian)
        let base = cal.startOfDay(for: Date())
        let date = cal.date(byAdding: .day, value: offsetDays, to: base) ?? base

        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0) // stable across simulator/device timezones
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Mock fallback

    private static func makeMockArtwork(dayID: String) -> DailyArtwork {
        let palette: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]

        var regions: [Region] = []
        var id = 0
        func add(_ number: Int, _ colorIndex: Int, _ path: Path) {
            regions.append(Region(id: id, number: number, colorIndex: colorIndex, path: path))
            id += 1
        }

        add(1, 0, Path { p in
            p.addRoundedRect(in: CGRect(x: 0.08, y: 0.10, width: 0.34, height: 0.30),
                             cornerSize: .init(width: 0.10, height: 0.10))
        })
        add(2, 1, Path { p in
            p.addRoundedRect(in: CGRect(x: 0.58, y: 0.10, width: 0.34, height: 0.30),
                             cornerSize: .init(width: 0.10, height: 0.10))
        })
        add(3, 2, Path { p in
            p.addRoundedRect(in: CGRect(x: 0.08, y: 0.60, width: 0.34, height: 0.30),
                             cornerSize: .init(width: 0.10, height: 0.10))
        })
        add(4, 3, Path { p in
            p.addRoundedRect(in: CGRect(x: 0.58, y: 0.60, width: 0.34, height: 0.30),
                             cornerSize: .init(width: 0.10, height: 0.10))
        })

        add(5, 6, Path(ellipseIn: CGRect(x: 0.38, y: 0.33, width: 0.24, height: 0.24)))
        add(6, 5, Path(ellipseIn: CGRect(x: 0.20, y: 0.42, width: 0.10, height: 0.10)))
        add(7, 4, Path(ellipseIn: CGRect(x: 0.70, y: 0.48, width: 0.08, height: 0.08)))
        add(8, 7, Path(ellipseIn: CGRect(x: 0.48, y: 0.74, width: 0.10, height: 0.10)))

        return DailyArtwork(
            id: dayID,
            title: "Today",
            completionMessage: "Nice. A little calmer now.",
            palette: palette,
            regions: regions
        )
    }
}
