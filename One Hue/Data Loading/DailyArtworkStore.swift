import SwiftUI
import Combine
import UIKit
import AVFoundation

@MainActor
final class ColoringStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var document: SVGDocument
    @Published private(set) var phase: ArtworkPhase = .painting
    @Published var selectedGroupIndex: Int? = nil
    @Published private(set) var loadFailed: Bool = false
    @Published private(set) var justCompletedGroupIndex: Int? = nil
    @Published private(set) var isPeeking: Bool = false
    @Published private(set) var peekUsesRemaining: Int = maxPeeksPerGame
    /// Incremented when the user re-taps an already-selected palette swatch,
    /// triggering a pulse flash in CanvasView even though selectedGroupIndex didn't change.
    @Published var pulseTrigger: UInt = 0
    /// Toggle to trigger a zoom-to-fit reset from outside CanvasView.
    @Published var resetZoomTrigger: Bool = false
    static let maxPeeksPerGame = 3

    @Published private(set) var filledElements: Set<Int> = [] {
        didSet {
            schedulePersist()
            checkCompletion()
        }
    }

    // MARK: - Spatial Index

    private(set) var spatialHash: SpatialHash!

    // MARK: - Haptics & Sound

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    /// Cached sound-enabled flag — avoids UserDefaults disk reads on every tap
    /// Refreshed via UserDefaults.didChangeNotification when settings toggle fires.
    private var soundEnabled: Bool = {
        UserDefaults.standard.object(forKey: "onehue.soundEnabled") == nil || UserDefaults.standard.bool(forKey: "onehue.soundEnabled")
    }()

    private var soundObserver: NSObjectProtocol? = nil

    private func observeSoundSetting() {
        guard soundObserver == nil else { return }
        soundObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.soundEnabled = UserDefaults.standard.object(forKey: "onehue.soundEnabled") == nil || UserDefaults.standard.bool(forKey: "onehue.soundEnabled")
        }
    }

    private var fillPlayer: AVAudioPlayer? = {
        // .ambient + .mixWithOthers so SFX and background music coexist
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let url = Bundle.main.url(forResource: "bloop", withExtension: "m4a") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.15
        player?.enableRate = true
        player?.prepareToPlay()
        return player
    }()

    private var dingPlayer: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "ding", withExtension: "wav") else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.01
        player?.prepareToPlay()
        return player
    }()


    /// Play the boop sound + light haptic — for UI button feedback
    func playBloop() {
        lightHaptic.impactOccurred()
        if soundEnabled {
            fillPlayer?.currentTime = 0
            fillPlayer?.play()
        }
    }

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

    /// Number of grouped elements still unfilled across the entire artwork.
    var globalRemaining: Int {
        document.groupedIndices.subtracting(filledElements).count
    }

    var selectedGroup: SVGColorGroup? {
        guard let idx = selectedGroupIndex, idx < document.groups.count else { return nil }
        return document.groups[idx]
    }

    // MARK: - Available Artworks

    private(set) var currentArtworkIndex: Int = 0
    private(set) var previousArtworkIndex: Int? = nil

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
        let cached = SVGDocumentCache.shared.document(for: artwork)
        let doc = cached ?? SVGDocument.empty(id: "fallback")
        self.currentArtworkIndex = index
        self.document = doc
        self.loadFailed = (cached == nil)
        self.spatialHash = SpatialHash(viewBox: doc.viewBox, elements: doc.elements)
        self.filledElements = Self.loadProgress(for: doc.id)
        // Fresh artwork: no color selected (user picks). Resume: auto-select largest group.
        self.selectedGroupIndex = filledElements.isEmpty ? nil : Self.largestIncompleteGroup(in: doc.groups, filled: filledElements)

        if filledElements.count >= doc.totalElements && doc.totalElements > 0 {
            phase = .complete
            Task { await CompletionService.shared.fetchCount(artworkID: artwork.id) }
        }
    }

    // MARK: - Artwork Switching

    func loadArtwork(at index: Int) {
        observeSoundSetting()
        persistNow() // flush before switching
        autoCompleteEnabled = false
        finishTimer?.invalidate(); finishTimer = nil; finishQueue.removeAll()
        completionPending = false
        findUsesRemaining = Self.maxFindsPerGame
        peekUsesRemaining = Self.maxPeeksPerGame
        tapCount = 0
        autoGrabbedCount = 0
        isPeeking = false
        let catalog = Artwork.catalog
        guard index >= 0, index < catalog.count else { return }
        previousArtworkIndex = currentArtworkIndex
        let artwork = catalog[index]
        let cached = SVGDocumentCache.shared.document(for: artwork)
        let doc = cached ?? SVGDocument.empty(id: "fallback")
        loadFailed = (cached == nil)
        currentArtworkIndex = index
        document = doc
        spatialHash = SpatialHash(viewBox: doc.viewBox, elements: doc.elements)
        filledElements = Self.loadProgress(for: doc.id)
        // Auto-select largest incomplete group — even on fresh artworks so the user
        // can start tapping immediately without choosing a color first.
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
        guard let selected = selectedGroupIndex,
              groupIdx == selected,
              groupIdx < document.groups.count else { return .wrongGroup }

        // Fill entire cluster containing the tapped element
        var toFill: Set<Int> = [elementIndex]
        if let clusterIdx = document.elementClusterMap[elementIndex] {
            toFill.formUnion(document.clusters[clusterIdx].elementIndices)
        }

        let clusterCount = toFill.count

        // Tiny-grab disabled — user prefers manual control
        // if !debugDisableTinyGrab {
        //     collectTinyNeighbors(from: toFill, groupIndex: groupIdx, into: &toFill)
        // }

        autoGrabbedCount += toFill.count - clusterCount
        tapCount += 1

        // Sound + haptic fire BEFORE fill mutation for snappier feedback
        lightHaptic.impactOccurred()
        if soundEnabled {
            fillPlayer?.currentTime = 0
            // Subtle pitch variation per tap — keeps repetitive tapping from feeling monotonous
            fillPlayer?.rate = Float.random(in: 0.92...1.08)
            fillPlayer?.play()
        }

        // Single mutation → one didSet trigger
        filledElements.formUnion(toFill)

        // Auto-complete group when 90%+ filled — forgiveness for invisible stragglers
        let group = document.groups[groupIdx]
        autoCompleteIfNearlyDone(group)

        // At 95%+ global, sweep remaining tiny elements across all groups
        autoSweepTinyRemnants()

        // Celebrate group completion — user picks next color manually (like HC)
        if group.elementIndices.allSatisfy({ filledElements.contains($0) }) {
            mediumHaptic.impactOccurred()
            if soundEnabled {
                dingPlayer?.currentTime = 0
                dingPlayer?.play()
            }
            justCompletedGroupIndex = groupIdx
            selectedGroupIndex = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard self?.justCompletedGroupIndex == groupIdx else { return }
                self?.justCompletedGroupIndex = nil
            }
        }

        return .filled
    }

    private func advanceToNextIncompleteGroup() {
        guard let current = selectedGroupIndex else { return }
        let count = document.groups.count
        for offset in 1...count {
            let idx = (current + offset) % count
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

    /// Complexity-scaled threshold: simpler artworks require higher fill %
    /// before auto-complete kicks in, so users get to finish them by hand.
    ///   ≤50 elements  → 100% (never auto-completes)
    ///   51–100        → 97%
    ///   101–200       → 95%
    ///   201+          → 90% (original behavior)
    private var autoCompleteThreshold: Double {
        let total = document.totalElements
        if total <= 50  { return 1.0 }
        if total <= 100 { return 0.97 }
        if total <= 200 { return 0.95 }
        return 0.90
    }

    private func autoCompleteIfNearlyDone(_ group: SVGColorGroup) {
        let total = group.elementIndices.count
        guard total > 0 else { return }
        let filled = group.elementIndices.filter { filledElements.contains($0) }.count
        guard Double(filled) / Double(total) >= autoCompleteThreshold else { return }

        // Only auto-fill tiny/invisible slivers — leave normal-sized pieces for the user
        let remaining = group.elementIndices.filter { !filledElements.contains($0) }
        let tinyRemaining = remaining.filter { idx in
            let el = document.elements[idx]
            return min(el.bounds.width, el.bounds.height) < tinyThreshold
        }
        guard !tinyRemaining.isEmpty else { return }
        filledElements.formUnion(tinyRemaining)
    }

    /// Sweep tiny remnants only on complex artworks (>50 elements).
    private func autoSweepTinyRemnants() {
        let total = document.totalElements
        guard total > 50,
              Double(filledElements.count) / Double(total) >= autoCompleteThreshold else { return }

        for idx in document.groupedIndices where !filledElements.contains(idx) {
            let el = document.elements[idx]
            if min(el.bounds.width, el.bounds.height) < tinyThreshold {
                filledElements.insert(idx)
            }
        }
    }

    /// When all remaining elements are tiny slivers, begin a gentle staggered fill.
    /// Won't trigger if any normal-sized piece remains — the user can tap those.
    private func autoCompleteGlobalIfNearlyDone() {
        // Already running a staggered finish — don't restart
        guard finishTimer == nil else { return }

        let leftover = document.groupedIndices.subtracting(filledElements)
        guard !leftover.isEmpty else { return }

        // Auto-complete if: all remaining are tiny, OR only 1-2 left (don't
        // make the user hunt for the very last pieces — just finish it).
        let fewEnoughToFinish = leftover.count <= 2
        let allTiny = leftover.allSatisfy { idx in
            let el = document.elements[idx]
            return min(el.bounds.width, el.bounds.height) < tinyThreshold
        }
        guard fewEnoughToFinish || allTiny else { return }

        startFinishingFill(indices: Array(leftover))
    }

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
    /// iPad uses halved thresholds so more pieces remain for the user to "hunt."
    static let tinyThresholdMax: CGFloat = 50
    private static let isIPad = UIDevice.current.userInterfaceIdiom == .pad
    private var tinyThreshold: CGFloat {
        let total = document.totalElements
        let base: CGFloat
        if total <= 50  { base = 15 }
        else if total <= 100 { base = 25 }
        else if total <= 200 { base = 35 }
        else { base = Self.tinyThresholdMax }
        return Self.isIPad ? base * 0.5 : base
    }
    /// How far (SVG units) to look for adjacent tiny elements
    private var neighborMargin: CGFloat {
        let total = document.totalElements
        let base: CGFloat
        if total <= 50  { base = 5 }
        else if total <= 100 { base = 10 }
        else if total <= 200 { base = 15 }
        else { base = 20 }
        return Self.isIPad ? base * 0.5 : base
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

    // MARK: - Debug / Testing

    /// Running count of user taps (tryFill calls that result in .filled).
    @Published private(set) var tapCount: Int = 0
    /// Total elements filled by tiny-neighbor auto-grab (not direct taps).
    @Published private(set) var autoGrabbedCount: Int = 0

    /// When true, skips the tiny-neighbor BFS so each tap only fills its cluster.
    /// Toggle via debug triple-tap on the tap counter overlay.
    var debugDisableTinyGrab: Bool {
        get { UserDefaults.standard.bool(forKey: "onehue.debug.disableTinyGrab") }
        set { UserDefaults.standard.set(newValue, forKey: "onehue.debug.disableTinyGrab"); objectWillChange.send() }
    }

    #if DEBUG
    /// Live canvas metrics published by CanvasView for the tester panel.
    struct CanvasDebugInfo {
        var viewportSize: CGSize = .zero
        var renderSize: CGSize = .zero
        var zoom: CGFloat = 1.0
        var offset: CGSize = .zero
        var contentOverflows: Bool = false
    }
    @Published var canvasDebug = CanvasDebugInfo()

    /// Fill every grouped element instantly — for testing completion flow.
    func fillAll() {
        filledElements = document.groupedIndices
    }
    #endif

    /// Maximum number of find-targets per color group. Prioritises the
    /// largest clusters so the finder highlights meaningful regions first
    /// and skips tiny specks that are tedious to hunt for.
    private static let maxFinderTargets = 10

    /// Finds the next unfilled cluster for the selected group and publishes
    /// its bounds so the canvas can zoom to it. Cycles through the largest
    /// clusters on repeated taps, capped at `maxFinderTargets`.
    func findNextUnfilled() {
        guard findUsesRemaining > 0 else { return }

        guard let selected = selectedGroupIndex else { return }

        if selected != lastFindGroup {
            findCycleIndex = 0
            lastFindGroup = selected
        }

        let unfilledClusters = document.clusters
            .filter { cluster in
                cluster.groupIndex == selected &&
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            UserDefaults.standard.set(true, forKey: "onehue.completed.\(self.currentArtwork.id)")
            self.recordCompletionDay()
            Task { await CompletionService.shared.reportCompletion(artworkID: self.currentArtwork.id) }
        }
    }

    // MARK: - Debug

    func debugForceComplete() {
        autoCompleteEnabled = false
        completionPending = false          // reset in case of prior attempt
        filledElements = document.groupedIndices
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
        guard let selected = selectedGroupIndex, selected < document.groups.count else { return }
        let group = document.groups[selected]
        if let nextIdx = group.elementIndices.first(where: { !filledElements.contains($0) }) {
            tryFill(elementIndex: nextIdx)
        } else {
            advanceToNextIncompleteGroup()
            guard let newSelected = selectedGroupIndex, newSelected < document.groups.count else { return }
            let newGroup = document.groups[newSelected]
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

    // MARK: - Streak

    /// Records today as a day with a completion and returns current streak length.
    func recordCompletionDay() {
        var dates = UserDefaults.standard.array(forKey: "onehue.completionDates") as? [String] ?? []
        let today = Self.utcDateString()
        if !dates.contains(today) {
            dates.append(today)
            UserDefaults.standard.set(dates, forKey: "onehue.completionDates")
        }
    }

    /// Current streak — consecutive days ending today (or yesterday if today is still in progress).
    static var currentStreak: Int {
        let dates = Set(UserDefaults.standard.array(forKey: "onehue.completionDates") as? [String] ?? [])
        guard !dates.isEmpty else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        var day = cal.startOfDay(for: Date())
        // Allow today or yesterday as the streak anchor
        let todayStr = utcDateString(for: day)
        if !dates.contains(todayStr) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var streak = 0
        while dates.contains(utcDateString(for: day)) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    private static func utcDateString(for date: Date? = nil) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: date ?? Date())
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
