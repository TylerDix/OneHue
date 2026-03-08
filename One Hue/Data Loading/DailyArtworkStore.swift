import SwiftUI
import Combine
import UIKit

// MARK: - Artwork Catalog

struct Artwork: Identifiable {
    let id: String               // stable key for persistence
    let fileName: String         // SVG filename without extension
    let displayName: String      // human-readable name shown in UI
    let completionMessage: String
}

extension Artwork {
    static let catalog: [Artwork] = [
        Artwork(id: "moon",      fileName: "moon",      displayName: "Moonlit Night",   completionMessage: "Tonight, this moon belongs to everyone who colored it."),
        Artwork(id: "sailboat",  fileName: "sailboat",  displayName: "Setting Sail",    completionMessage: "The wind doesn't care where you planned to go."),
        Artwork(id: "koi_pond",  fileName: "koi_pond",  displayName: "Koi Pond",        completionMessage: "Everything worth seeing moves slowly."),
        Artwork(id: "lantern",   fileName: "lantern",   displayName: "Paper Lanterns",  completionMessage: "A single flame can hold an entire evening."),
        Artwork(id: "home",      fileName: "home",      displayName: "The Lake House",  completionMessage: "The lake doesn't know how beautiful it is."),
    ]

    /// Deterministic daily artwork: same image for everyone on a given UTC date.
    /// Cycles through the catalog using days-since-epoch mod catalog size.
    static func today() -> (artwork: Artwork, index: Int) {
        let todayStr = CompletionService.todayUTC()
        return forDateString(todayStr)
    }

    static func forDateString(_ dateStr: String) -> (artwork: Artwork, index: Int) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        let date = f.date(from: dateStr) ?? Date()
        let daysSinceEpoch = Int(date.timeIntervalSince1970) / 86400
        let index = daysSinceEpoch % catalog.count
        return (catalog[index], index)
    }
}

@MainActor
final class ColoringStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var document: SVGDocument
    @Published private(set) var phase: ArtworkPhase = .painting
    @Published var selectedGroupIndex: Int = 0

    @Published private(set) var filledElements: Set<Int> = [] {
        didSet {
            persistProgress()
            checkCompletion()
        }
    }

    // MARK: - Spatial Index

    private(set) var spatialHash: SpatialHash!

    // MARK: - Derived

    var isComplete: Bool {
        filledElements.count >= document.totalElements && document.totalElements > 0
    }

    var progressFraction: Double {
        guard document.totalElements > 0 else { return 0 }
        return Double(filledElements.count) / Double(document.totalElements)
    }

    var progressText: String {
        "\(filledElements.count) / \(document.totalElements)"
    }

    var selectedGroup: SVGColorGroup {
        document.groups[selectedGroupIndex]
    }

    // MARK: - Available Artworks

    private(set) var currentArtworkIndex: Int = 0

    var currentArtwork: Artwork {
        Artwork.catalog[currentArtworkIndex]
    }

    // MARK: - Init

    init() {
        let (artwork, index) = Artwork.today()
        let doc = SVGParser.parse(artwork: artwork)
              ?? SVGDocument.empty(id: "fallback")
        self.currentArtworkIndex = index
        self.document = doc
        self.spatialHash = SpatialHash(viewBox: doc.viewBox, elements: doc.elements)
        self.filledElements = Self.loadProgress(for: doc.id)

        if filledElements.count >= doc.totalElements && doc.totalElements > 0 {
            phase = .complete
            Task { await CompletionService.shared.fetchCount(artworkID: artwork.id) }
        }
    }

    // MARK: - Artwork Switching

    func loadArtwork(at index: Int) {
        autoCompleteEnabled = false
        let catalog = Artwork.catalog
        guard index >= 0, index < catalog.count else { return }
        let artwork = catalog[index]
        let doc = SVGParser.parse(artwork: artwork)
              ?? SVGDocument.empty(id: "fallback")
        currentArtworkIndex = index
        document = doc
        spatialHash = SpatialHash(viewBox: doc.viewBox, elements: doc.elements)
        selectedGroupIndex = 0
        filledElements = Self.loadProgress(for: doc.id)
        phase = (filledElements.count >= doc.totalElements && doc.totalElements > 0) ? .complete : .painting
    }

    func nextArtwork() {
        loadArtwork(at: (currentArtworkIndex + 1) % Artwork.catalog.count)
    }

    func previousArtwork() {
        loadArtwork(at: (currentArtworkIndex - 1 + Artwork.catalog.count) % Artwork.catalog.count)
    }

    // MARK: - Fill

    enum FillResult { case filled, wrongGroup, alreadyFilled }

    @discardableResult
    func tryFill(elementIndex: Int) -> FillResult {
        guard elementIndex >= 0, elementIndex < document.elements.count else { return .wrongGroup }
        guard !filledElements.contains(elementIndex) else { return .alreadyFilled }

        let groupIdx = document.elementGroupMap[elementIndex] ?? -1
        guard groupIdx == selectedGroupIndex else { return .wrongGroup }

        // Fill entire cluster containing the tapped element
        var toFill: Set<Int> = [elementIndex]
        if let clusterIdx = document.elementClusterMap[elementIndex] {
            toFill.formUnion(document.clusters[clusterIdx].elementIndices)
        }

        // Also collect tiny neighbors near any element in the filled cluster
        collectTinyNeighbors(from: toFill, groupIndex: groupIdx, into: &toFill)

        // Single mutation → one didSet trigger
        filledElements.formUnion(toFill)

        // Auto-complete group when 95%+ filled — forgiveness for invisible stragglers
        let group = document.groups[groupIdx]
        autoCompleteIfNearlyDone(group)

        // Auto-advance to next incomplete group
        if group.elementIndices.allSatisfy({ filledElements.contains($0) }) {
            advanceToNextIncompleteGroup()
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        return .filled
    }

    private func advanceToNextIncompleteGroup() {
        let count = document.groups.count
        for offset in 1...count {
            let idx = (selectedGroupIndex + offset) % count
            let group = document.groups[idx]
            if group.elementIndices.contains(where: { !filledElements.contains($0) }) {
                selectedGroupIndex = idx
                return
            }
        }
    }

    // MARK: - Auto-Complete Near-Done Groups

    /// When a group reaches this fraction filled, auto-fill the rest.
    private let autoCompleteThreshold: Double = 0.95

    private func autoCompleteIfNearlyDone(_ group: SVGColorGroup) {
        let total = group.elementIndices.count
        guard total > 0 else { return }
        let filled = group.elementIndices.filter { filledElements.contains($0) }.count
        guard Double(filled) / Double(total) >= autoCompleteThreshold else { return }

        let remaining = Set(group.elementIndices.filter { !filledElements.contains($0) })
        guard !remaining.isEmpty else { return }
        filledElements.formUnion(remaining)
    }

    // MARK: - Auto-Fill Tiny Neighbors

    /// SVG-unit threshold: elements with min(width, height) below this are "tiny"
    private let tinyThreshold: CGFloat = 90
    /// How far (SVG units) to look for adjacent tiny elements
    private let neighborMargin: CGFloat = 45

    /// BFS cascade: starting from all seed elements, find touching tiny same-group
    /// elements and add them to `toFill`.
    private func collectTinyNeighbors(from seeds: Set<Int>, groupIndex: Int, into toFill: inout Set<Int>) {
        let group = document.groups[groupIndex]
        var queue = Array(seeds)

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let zone = document.elements[current].bounds.insetBy(dx: -neighborMargin, dy: -neighborMargin)

            for idx in group.elementIndices {
                guard !filledElements.contains(idx), !toFill.contains(idx) else { continue }
                let el = document.elements[idx]
                guard min(el.bounds.width, el.bounds.height) < tinyThreshold else { continue }
                guard zone.intersects(el.bounds) else { continue }
                toFill.insert(idx)
                queue.append(idx)
            }
        }
    }

    func resetProgress() {
        filledElements = []
        phase = .painting
        Self.clearProgress(for: document.id)
    }

    // MARK: - Find Next Unfilled

    @Published private(set) var findTargetToken: UInt = 0
    private(set) var findTargetBounds: CGRect = .zero
    private var findCycleIndex: Int = 0
    private var lastFindGroup: Int = -1

    /// Finds the next unfilled cluster for the selected group and publishes
    /// its bounds so the canvas can zoom to it. Cycles through clusters on
    /// repeated taps.
    func findNextUnfilled() {
        if selectedGroupIndex != lastFindGroup {
            findCycleIndex = 0
            lastFindGroup = selectedGroupIndex
        }

        let unfilledClusters = document.clusters.filter { cluster in
            cluster.groupIndex == selectedGroupIndex &&
            cluster.elementIndices.contains(where: { !filledElements.contains($0) })
        }

        guard !unfilledClusters.isEmpty else { return }

        if findCycleIndex >= unfilledClusters.count {
            findCycleIndex = 0
        }

        let target = unfilledClusters[findCycleIndex]
        findCycleIndex += 1

        findTargetBounds = target.bounds
        findTargetToken &+= 1
    }

    // MARK: - Completion

    private func checkCompletion() {
        guard isComplete, phase != .complete else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { phase = .complete }
        Task { await CompletionService.shared.reportCompletion(artworkID: currentArtwork.id) }
    }

    // MARK: - Debug

    func debugForceComplete() {
        autoCompleteEnabled = false
        filledElements = Set(0..<document.elements.count)
        phase = .complete
        Task { await CompletionService.shared.reportCompletion(artworkID: currentArtwork.id) }
    }

    // MARK: - Auto Complete

    @Published var autoCompleteEnabled: Bool = false {
        didSet {
            if autoCompleteEnabled { startAutoComplete() }
            else { stopAutoComplete() }
        }
    }

    private var autoCompleteTimer: Timer?

    private func startAutoComplete() {
        stopAutoComplete()
        autoCompleteTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.autoFillNextElement()
            }
        }
    }

    private func stopAutoComplete() {
        autoCompleteTimer?.invalidate()
        autoCompleteTimer = nil
    }

    private func autoFillNextElement() {
        guard !isComplete else {
            autoCompleteEnabled = false
            return
        }
        let group = document.groups[selectedGroupIndex]
        if let nextIdx = group.elementIndices.first(where: { !filledElements.contains($0) }) {
            tryFill(elementIndex: nextIdx)
        } else {
            advanceToNextIncompleteGroup()
            let newGroup = document.groups[selectedGroupIndex]
            if let nextIdx = newGroup.elementIndices.first(where: { !filledElements.contains($0) }) {
                tryFill(elementIndex: nextIdx)
            }
        }
    }

    // MARK: - Persistence

    private func persistProgress() {
        let array = Array(filledElements)
        UserDefaults.standard.set(array, forKey: Self.progressKey(for: document.id))
    }

    private static func loadProgress(for docID: String) -> Set<Int> {
        let array = UserDefaults.standard.array(forKey: progressKey(for: docID)) as? [Int] ?? []
        return Set(array)
    }

    private static func clearProgress(for docID: String) {
        UserDefaults.standard.removeObject(forKey: progressKey(for: docID))
    }

    private static func progressKey(for docID: String) -> String {
        "onehue.svg.\(docID)"
    }

}
