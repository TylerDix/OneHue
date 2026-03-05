import SwiftUI
import Combine

@MainActor
final class DailyArtworkStore: ObservableObject {

    // MARK: - Published state

    @Published private(set) var artwork: DailyArtwork
    @Published var selectedColorIndex: Int = 0
    @Published var filledRegionIDs: Set<Int> = [] {
        didSet { persistProgress() }
    }

    // MARK: - Init

    init() {
        self.artwork = Self.makeMockArtworkForToday()
        self.filledRegionIDs = Self.loadProgress(for: artwork.id)
    }

    // MARK: - Derived

    var isComplete: Bool {
        filledRegionIDs.count == artwork.regions.count
    }

    var progressText: String {
        "\(filledRegionIDs.count) / \(artwork.regions.count)"
    }

    // MARK: - Actions

    /// Enforces "correct color only".
    /// Returns true if fill happened (or was already filled), false if wrong color.
    func tryFill(regionID: Int) -> Bool {
        guard let region = artwork.regions.first(where: { $0.id == regionID }) else { return false }
        if filledRegionIDs.contains(regionID) { return true }

        guard selectedColorIndex == region.colorIndex else { return false }

        filledRegionIDs.insert(regionID)
        return true
    }

    func resetToday() {
        filledRegionIDs = []
    }

    // MARK: - Persistence (UserDefaults)

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

    // MARK: - Mock Artwork (replace later with SVG -> regions)

    private static func makeMockArtworkForToday() -> DailyArtwork {
        let palette: [Color] = [
            .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .white, .gray
        ]

        var regions: [Region] = []
        var id = 0
        func add(_ number: Int, _ colorIndex: Int, _ path: Path) {
            regions.append(Region(id: id, number: number, colorIndex: colorIndex, path: path))
            id += 1
        }

        add(1, 0, Path { p in p.addRoundedRect(in: CGRect(x: 0.08, y: 0.10, width: 0.34, height: 0.30),
                                               cornerSize: .init(width: 0.10, height: 0.10)) })
        add(2, 1, Path { p in p.addRoundedRect(in: CGRect(x: 0.58, y: 0.10, width: 0.34, height: 0.30),
                                               cornerSize: .init(width: 0.10, height: 0.10)) })
        add(3, 2, Path { p in p.addRoundedRect(in: CGRect(x: 0.08, y: 0.60, width: 0.34, height: 0.30),
                                               cornerSize: .init(width: 0.10, height: 0.10)) })
        add(4, 3, Path { p in p.addRoundedRect(in: CGRect(x: 0.58, y: 0.60, width: 0.34, height: 0.30),
                                               cornerSize: .init(width: 0.10, height: 0.10)) })

        add(5, 6, Path(ellipseIn: CGRect(x: 0.38, y: 0.33, width: 0.24, height: 0.24)))
        add(6, 5, Path(ellipseIn: CGRect(x: 0.20, y: 0.42, width: 0.10, height: 0.10)))
        add(7, 4, Path(ellipseIn: CGRect(x: 0.70, y: 0.48, width: 0.08, height: 0.08)))
        add(8, 7, Path(ellipseIn: CGRect(x: 0.48, y: 0.74, width: 0.10, height: 0.10)))

        return DailyArtwork(
            id: Self.todayString(),
            title: "Today",
            completionMessage: "Nice. A little calmer now.",
            palette: palette,
            regions: regions
        )
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
