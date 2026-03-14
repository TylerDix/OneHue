import SwiftUI
import Combine
import UIKit

@MainActor
final class ColoringStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var document: SVGDocument
    @Published private(set) var phase: ArtworkPhase = .painting
    @Published var selectedGroupIndex: Int = 0
    @Published private(set) var justCompletedGroupIndex: Int? = nil
    @Published private(set) var isPeeking: Bool = false
    @Published private(set) var peekUsesRemaining: Int = maxPeeksPerGame
    static let maxPeeksPerGame = 3

    @Published private(set) var filledElements: Set<Int> = [] {
        didSet {
            schedulePersist()
            checkCompletion()
        }
    }

    // MARK: - Spatial Index

    private(set) var spatialHash: SpatialHash!

    // MARK: - Undo Stack

    /// Each entry records the elements added by a single fill action.
    private var undoStack: [Set<Int>] = []
    private static let maxUndoDepth = 30

    var canUndo: Bool { !undoStack.isEmpty && phase == .painting && finishTimer == nil }

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
        guard selectedGroupIndex < document.groups.count else {
            return document.groups[0]  // sentinel fallback
        }
        return document.groups[selectedGroupIndex]
    }

    // MARK: - Available Artworks

    private(set) var currentArtworkIndex: Int = 0

    var currentArtwork: Artwork {
        let catalog = Artwork.catalog
        guard currentArtworkIndex >= 0, currentArtworkIndex < catalog.count else {
            return catalog[0]
        }
        return catalog[currentArtworkIndex]
    }

    // MARK: - Init

    init() {
        let (artwork, index) = Artwork.today()
        let doc = SVGDocumentCache.shared.document(for: artwork)
              ?? SVGDocument.empty(id: "fallback")
        self.currentArtworkIndex = index
        self.document = doc
        self.spatialHash = SpatialHash(viewBox: doc.viewBox, elements: doc.elements)
        self.filledElements = Self.loadProgress(for: doc.id)
        self.selectedGroupIndex = Self.largestIncompleteGroup(in: doc.groups, filled: filledElements)

        if filledElements.count >= doc.totalElements && doc.totalElements > 0 {
            phase = .complete
            Task { await CompletionService.shared.fetchCount(artworkID: artwork.id) }
        }
    }

    // MARK: - Artwork Switching

    func loadArtwork(at index: Int) {
        persistNow() // flush before switching
        autoCompleteEnabled = false
        finishTimer?.invalidate(); finishTimer = nil; finishQueue.removeAll()
        completionPending = false
        undoStack.removeAll()
        findUsesRemaining = Self.maxFindsPerGame
        peekUsesRemaining = Self.maxPeeksPerGame
        isPeeking = false
        let catalog = Artwork.catalog
        guard index >= 0, index < catalog.count else { return }
        let artwork = catalog[index]
        let doc = SVGDocumentCache.shared.document(for: artwork)
              ?? SVGDocument.empty(id: "fallback")
        currentArtworkIndex = index
        document = doc
        spatialHash = SpatialHash(viewBox: doc.viewBox, elements: doc.elements)
        filledElements = Self.loadProgress(for: doc.id)
        selectedGroupIndex = Self.largestIncompleteGroup(in: doc.groups, filled: filledElements)
        phase = (filledElements.count >= doc.totalElements && doc.totalElements > 0) ? .complete : .painting
    }

    func nextArtwork() {
        loadArtwork(at: (currentArtworkIndex + 1) % Artwork.catalog.count)
    }

    /// Advances to the next incomplete artwork, wrapping around. Falls back to
    /// plain `nextArtwork()` if every artwork is already completed.
    func nextIncompleteArtwork() {
        let count = Artwork.catalog.count
        for offset in 1..<count {
            let idx = (currentArtworkIndex + offset) % count
            if !Self.isArtworkCompleted(Artwork.catalog[idx].id) {
                loadArtwork(at: idx)
                return
            }
        }
        // Everything completed — just advance one
        nextArtwork()
    }

    func previousArtwork() {
        loadArtwork(at: (currentArtworkIndex - 1 + Artwork.catalog.count) % Artwork.catalog.count)
    }

    // MARK: - Fill

    enum FillResult { case filled, wrongGroup, alreadyFilled }

    @discardableResult
    func tryFill(elementIndex: Int) -> FillResult {
        guard finishTimer == nil else { return .alreadyFilled } // finishing cascade in progress
        guard elementIndex >= 0, elementIndex < document.elements.count else { return .wrongGroup }
        guard !filledElements.contains(elementIndex) else { return .alreadyFilled }

        let groupIdx = document.elementGroupMap[elementIndex] ?? -1
        guard groupIdx == selectedGroupIndex,
              groupIdx < document.groups.count else { return .wrongGroup }

        // Snapshot before any mutations so undo captures the full delta
        let beforeFill = filledElements

        // Fill entire cluster containing the tapped element
        var toFill: Set<Int> = [elementIndex]
        if let clusterIdx = document.elementClusterMap[elementIndex] {
            toFill.formUnion(document.clusters[clusterIdx].elementIndices)
        }

        // Also collect tiny neighbors near any element in the filled cluster
        collectTinyNeighbors(from: toFill, groupIndex: groupIdx, into: &toFill)

        // Single mutation → one didSet trigger
        filledElements.formUnion(toFill)

        // Auto-complete group when 90%+ filled — forgiveness for invisible stragglers
        let group = document.groups[groupIdx]
        autoCompleteIfNearlyDone(group)

        // At 95%+ global, sweep remaining tiny elements across all groups
        autoSweepTinyRemnants()

        // Global auto-complete: if only a handful of elements remain across the
        // entire artwork, fill them all so users never get stuck on invisible pixels.
        autoCompleteGlobalIfNearlyDone()

        // Record undo action: full delta including any auto-completed elements
        let fullDelta = filledElements.subtracting(beforeFill)
        if !fullDelta.isEmpty {
            undoStack.append(fullDelta)
            if undoStack.count > Self.maxUndoDepth {
                undoStack.removeFirst()
            }
        }

        // Auto-advance to next incomplete group
        if group.elementIndices.allSatisfy({ filledElements.contains($0) }) {
            mediumHaptic.impactOccurred()
            justCompletedGroupIndex = groupIdx
            advanceToNextIncompleteGroup()
            // Clear after palette has time to show checkmark
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                guard self?.justCompletedGroupIndex == groupIdx else { return }
                self?.justCompletedGroupIndex = nil
            }
        }

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

    /// Returns the group index with the most unfilled elements — puts the
    /// largest paintable area on the brush so the user can start immediately.
    private static func largestIncompleteGroup(
        in groups: [SVGColorGroup], filled: Set<Int>
    ) -> Int {
        var bestIdx = 0
        var bestCount = 0
        for (i, group) in groups.enumerated() {
            let unfilled = group.elementIndices.count
                - group.elementIndices.filter { filled.contains($0) }.count
            if unfilled > bestCount {
                bestCount = unfilled
                bestIdx = i
            }
        }
        return bestIdx
    }

    // MARK: - Auto-Complete Near-Done Groups

    /// Auto-complete threshold: 100% — user must fill every cell.
    private var autoCompleteThreshold: Double { 1.0 }

    private func autoCompleteIfNearlyDone(_ group: SVGColorGroup) {
        let total = group.elementIndices.count
        guard total > 0 else { return }
        let filled = group.elementIndices.filter { filledElements.contains($0) }.count
        guard Double(filled) / Double(total) >= autoCompleteThreshold else { return }

        let remaining = Set(group.elementIndices.filter { !filledElements.contains($0) })
        guard !remaining.isEmpty else { return }
        filledElements.formUnion(remaining)
    }

    /// Sweep tiny remnants — disabled while testing 100% completion.
    private func autoSweepTinyRemnants() {}

    /// Global auto-complete — disabled while testing 100% completion.
    private func autoCompleteGlobalIfNearlyDone() {}

    // MARK: - Staggered Finishing Fill

    private var finishTimer: Timer?
    private var finishQueue: [Int] = []

    /// Fills remaining elements one-by-one with a short delay between each,
    /// so the artwork completes with a gentle cascade instead of a hard snap.
    private func startFinishingFill(indices: [Int]) {
        // Shuffle for a natural scattered feel, then drain via timer
        finishQueue = indices.shuffled()
        // Interval scales with count: fast for few, leisurely for many
        let interval = min(0.12, max(0.04, 0.6 / Double(finishQueue.count)))
        finishTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.drainFinishQueue() }
        }
    }

    private func drainFinishQueue() {
        guard !finishQueue.isEmpty else {
            finishTimer?.invalidate()
            finishTimer = nil
            return
        }
        let idx = finishQueue.removeFirst()
        filledElements.insert(idx)
    }

    // MARK: - Auto-Fill Tiny Neighbors

    /// SVG-unit threshold: elements with min(width, height) below this are "tiny".
    /// Scaled by artwork complexity so easy artworks don't auto-grab too many cells.
    static let tinyThresholdMax: CGFloat = 90
    private var tinyThreshold: CGFloat {
        let total = document.totalElements
        if total <= 50  { return 25 }
        if total <= 100 { return 45 }
        if total <= 200 { return 65 }
        return Self.tinyThresholdMax
    }
    /// How far (SVG units) to look for adjacent tiny elements
    private var neighborMargin: CGFloat {
        let total = document.totalElements
        if total <= 50  { return 10 }
        if total <= 100 { return 20 }
        if total <= 200 { return 30 }
        return 45
    }

    /// BFS cascade: starting from all seed elements, find touching tiny same-group
    /// elements and add them to `toFill`. Uses spatial hash for O(nearby) lookup
    /// instead of scanning all group elements per queue item.
    private func collectTinyNeighbors(from seeds: Set<Int>, groupIndex: Int, into toFill: inout Set<Int>) {
        guard groupIndex < document.groups.count else { return }
        let groupElements = Set(document.groups[groupIndex].elementIndices)
        var queue = Array(seeds)

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let zone = document.elements[current].bounds.insetBy(dx: -neighborMargin, dy: -neighborMargin)

            for idx in spatialHash.candidates(in: zone) {
                guard groupElements.contains(idx) else { continue }
                guard !filledElements.contains(idx), !toFill.contains(idx) else { continue }
                let el = document.elements[idx]
                guard min(el.bounds.width, el.bounds.height) < tinyThreshold else { continue }
                guard zone.intersects(el.bounds) else { continue }
                toFill.insert(idx)
                queue.append(idx)
            }
        }
    }

    // MARK: - Undo

    func undo() {
        guard let lastAction = undoStack.popLast() else { return }
        filledElements.subtract(lastAction)

        // Ensure the selected group has unfilled elements; if not, switch to one that does
        if selectedGroupIndex < document.groups.count {
            let group = document.groups[selectedGroupIndex]
            let hasUnfilled = group.elementIndices.contains { !filledElements.contains($0) }
            if !hasUnfilled {
                advanceToNextIncompleteGroup()
            }
        }

        // lightHaptic.impactOccurred()
    }

    // MARK: - Peek

    /// Temporarily reveals the finished artwork, then fades back.
    func peek() {
        guard peekUsesRemaining > 0, !isPeeking, phase == .painting else { return }
        peekUsesRemaining -= 1
        isPeeking = true
        lightHaptic.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isPeeking = false
        }
    }

    func resetProgress() {
        finishTimer?.invalidate(); finishTimer = nil; finishQueue.removeAll()
        completionPending = false
        undoStack.removeAll()
        findUsesRemaining = Self.maxFindsPerGame
        filledElements = []
        phase = .painting
        Self.clearProgress(for: document.id)
        UserDefaults.standard.removeObject(forKey: "onehue.completed.\(currentArtwork.id)")
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

    /// Total find-clicks allowed per artwork before the scope button hides.
    static let maxFindsPerGame = 4
    @Published private(set) var findUsesRemaining: Int = maxFindsPerGame

    /// Maximum number of find-targets per color group. Prioritises the
    /// largest clusters so the finder highlights meaningful regions first
    /// and skips tiny specks that are tedious to hunt for.
    private static let maxFinderTargets = 10

    /// Finds the next unfilled cluster for the selected group and publishes
    /// its bounds so the canvas can zoom to it. Cycles through the largest
    /// clusters on repeated taps, capped at `maxFinderTargets`.
    func findNextUnfilled() {
        guard findUsesRemaining > 0 else { return }

        if selectedGroupIndex != lastFindGroup {
            findCycleIndex = 0
            lastFindGroup = selectedGroupIndex
        }

        let unfilledClusters = document.clusters
            .filter { cluster in
                cluster.groupIndex == selectedGroupIndex &&
                cluster.elementIndices.contains(where: { !filledElements.contains($0) })
            }
            .sorted { $0.bounds.width * $0.bounds.height > $1.bounds.width * $1.bounds.height }
            .prefix(Self.maxFinderTargets)

        guard !unfilledClusters.isEmpty else { return }

        if findCycleIndex >= unfilledClusters.count {
            findCycleIndex = 0
        }

        let target = unfilledClusters[findCycleIndex]
        findCycleIndex += 1

        findTargetBounds = target.bounds
        findTargetToken &+= 1
        findUsesRemaining -= 1
    }

    // MARK: - Completion

    private var completionPending = false

    private func checkCompletion() {
        guard isComplete, phase != .complete, !completionPending else { return }

        // Let the user see the final filled state for a breath before transitioning
        completionPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.isComplete, self.phase != .complete else { return }
            withAnimation(.easeOut(duration: 0.6)) { self.phase = .complete }
            UserDefaults.standard.set(true, forKey: "onehue.completed.\(self.currentArtwork.id)")
            Task { await CompletionService.shared.reportCompletion(artworkID: self.currentArtwork.id) }
        }
    }

    // MARK: - Debug

    func debugForceComplete() {
        autoCompleteEnabled = false
        filledElements = document.groupedIndices
        phase = .complete
        Task { await CompletionService.shared.reportCompletion(artworkID: currentArtwork.id) }
    }

    /// Fills everything except ~5 cells spread across groups, so you can
    /// manually tap the last few and test the completion experience.
    func debugNearlyComplete() {
        autoCompleteEnabled = false
        var allIndices = document.groupedIndices

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
        guard selectedGroupIndex < document.groups.count else { return }
        let group = document.groups[selectedGroupIndex]
        if let nextIdx = group.elementIndices.first(where: { !filledElements.contains($0) }) {
            tryFill(elementIndex: nextIdx)
        } else {
            advanceToNextIncompleteGroup()
            guard selectedGroupIndex < document.groups.count else { return }
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
