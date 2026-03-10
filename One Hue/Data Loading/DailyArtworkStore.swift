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
        Artwork(id: "home",      fileName: "home",      displayName: "The Lake House",    completionMessage: "The lake doesn't know how beautiful it is."),
        Artwork(id: "japanese",       fileName: "japanese",       displayName: "Wisteria Garden",   completionMessage: "The garden remembers every footstep it has softened."),
        Artwork(id: "northerlights", fileName: "northerlights", displayName: "Northern Lights",   completionMessage: "The sky practices its colors when no one is keeping score."),
        Artwork(id: "cobble",        fileName: "cobble",        displayName: "Cobblestone Lane",  completionMessage: "Old streets don't give directions. They give perspective."),
        Artwork(id: "temple",        fileName: "temple",        displayName: "The Temple",        completionMessage: "The bell doesn't ring for anyone in particular."),
        Artwork(id: "lighthouse",    fileName: "lighthouse",    displayName: "The Lighthouse",    completionMessage: "It never asks if anyone is watching."),
        Artwork(id: "baloon",        fileName: "baloon",        displayName: "Hot Air Balloon",   completionMessage: "The ground looks different when you stop holding on to it."),
        Artwork(id: "firefly",       fileName: "firefly",       displayName: "Fireflies",         completionMessage: "They carry their own light and never explain it."),
        Artwork(id: "fishing",       fileName: "fishing",       displayName: "Gone Fishing",      completionMessage: "The river has nowhere to be, and neither do you."),
        Artwork(id: "canyon",        fileName: "canyon",        displayName: "The Canyon",        completionMessage: "The river doesn't hurry, and the canyon is its proof."),
        Artwork(id: "desert",        fileName: "desert",        displayName: "Desert Dusk",       completionMessage: "The sand remembers the shape of the wind."),
        Artwork(id: "cityMarket",    fileName: "cityMarket",    displayName: "City Market",       completionMessage: "A thousand strangers, all choosing the same afternoon."),
        Artwork(id: "starFish",      fileName: "starFish",      displayName: "Starfish",          completionMessage: "The tide gives back more than it takes."),
        Artwork(id: "snowyVillage",  fileName: "snowyVillage",  displayName: "Snowy Village",     completionMessage: "Snow makes every rooftop the same height."),
        Artwork(id: "airBalloon",    fileName: "airBalloon",    displayName: "Air Balloon",       completionMessage: "From up here, every worry is the size of a house."),
        Artwork(id: "bench",         fileName: "bench",         displayName: "Park Bench",        completionMessage: "The best conversations happen where no one is in a hurry."),
        Artwork(id: "cathedral",     fileName: "cathedral",     displayName: "The Cathedral",     completionMessage: "Stone remembers what hands intended."),
        Artwork(id: "cherryBlossoms", fileName: "cherryBlossoms", displayName: "Cherry Blossoms", completionMessage: "They bloom knowing they won't stay."),
        Artwork(id: "fairy",         fileName: "fairy",         displayName: "Fairy",             completionMessage: "Some things are only visible when you stop trying to see them."),
        Artwork(id: "fishingBoats",  fileName: "fishingBoats",  displayName: "Fishing Boats",     completionMessage: "The harbor is safe, but that's not what boats are for."),
        Artwork(id: "highway",       fileName: "highway",       displayName: "The Highway",       completionMessage: "Every road was someone's first step away from standing still."),
        Artwork(id: "lantern2",      fileName: "lantern2",      displayName: "Lanterns II",       completionMessage: "Light finds its way without asking for directions."),
        Artwork(id: "mountain",      fileName: "mountain",      displayName: "The Mountain",      completionMessage: "It was already there before anyone thought to climb it."),
        Artwork(id: "turtles",       fileName: "turtles",       displayName: "Sea Turtles",       completionMessage: "They carry their home and never call it heavy."),
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
            schedulePersist()
            checkCompletion()
        }
    }

    // MARK: - Spatial Index

    private(set) var spatialHash: SpatialHash!

    // MARK: - Haptics (pre-prepared for snappy response)

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

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
        persistNow() // flush before switching
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

        // Global auto-complete: if only a handful of elements remain across the
        // entire artwork, fill them all so users never get stuck on invisible pixels.
        autoCompleteGlobalIfNearlyDone()

        // Auto-advance to next incomplete group
        if group.elementIndices.allSatisfy({ filledElements.contains($0) }) {
            advanceToNextIncompleteGroup()
        }

        lightHaptic.impactOccurred()
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
    private let autoCompleteThreshold: Double = 0.90

    private func autoCompleteIfNearlyDone(_ group: SVGColorGroup) {
        let total = group.elementIndices.count
        guard total > 0 else { return }
        let filled = group.elementIndices.filter { filledElements.contains($0) }.count
        guard Double(filled) / Double(total) >= autoCompleteThreshold else { return }

        let remaining = Set(group.elementIndices.filter { !filledElements.contains($0) })
        guard !remaining.isEmpty else { return }
        filledElements.formUnion(remaining)
    }

    /// When the overall artwork has very few elements remaining, auto-fill them all.
    private func autoCompleteGlobalIfNearlyDone() {
        let total = document.elements.count
        let remaining = total - filledElements.count
        // If 3 or fewer elements left, or 99%+ filled, finish the artwork
        guard remaining > 0, remaining <= 3 || Double(filledElements.count) / Double(total) >= 0.99 else { return }
        let allIndices = Set(0..<total)
        filledElements.formUnion(allIndices)
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

    /// Incremented to tell CanvasView to slowly drift back to center.
    @Published private(set) var completionDriftToken: UInt = 0

    func triggerCompletionDrift() {
        completionDriftToken &+= 1
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

        // Soft double-tap haptic
        mediumHaptic.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.lightHaptic.impactOccurred()
        }

        withAnimation { phase = .complete }
        UserDefaults.standard.set(true, forKey: "onehue.completed.\(currentArtwork.id)")
        Task { await CompletionService.shared.reportCompletion(artworkID: currentArtwork.id) }
    }

    // MARK: - Debug

    func debugForceComplete() {
        autoCompleteEnabled = false
        filledElements = Set(0..<document.elements.count)
        phase = .complete
        Task { await CompletionService.shared.reportCompletion(artworkID: currentArtwork.id) }
    }

    /// Fills everything except ~5 cells spread across groups, so you can
    /// manually tap the last few and test the completion experience.
    func debugNearlyComplete() {
        autoCompleteEnabled = false
        var allIndices = Set(0..<document.elements.count)

        // Keep a few unfilled cells from the last group that has elements
        let keep = 5
        var kept = 0
        for group in document.groups.reversed() {
            for idx in group.elementIndices.reversed() {
                guard kept < keep else { break }
                allIndices.remove(idx)
                kept += 1
            }
            if kept >= keep { break }
        }

        filledElements = allIndices
        phase = .painting
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
            guard let self else { return }
            Task { @MainActor in
                self.autoFillNextElement()
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

    // MARK: - Persistence (debounced)

    private var persistTimer: Timer?

    private func schedulePersist() {
        persistTimer?.invalidate()
        persistTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.persistNow()
            }
        }
    }

    func persistNow() {
        persistTimer?.invalidate()
        persistTimer = nil
        let array = Array(filledElements)
        UserDefaults.standard.set(array, forKey: Self.progressKey(for: document.id))
    }

    /// Checks if an artwork has been completed (proper flag, not heuristic).
    static func isArtworkCompleted(_ artworkID: String) -> Bool {
        UserDefaults.standard.bool(forKey: "onehue.completed.\(artworkID)")
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
