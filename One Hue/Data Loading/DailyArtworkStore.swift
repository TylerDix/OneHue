import SwiftUI
import Combine

@MainActor
final class DailyArtworkStore: ObservableObject {

    // MARK: - Published State

    @Published private(set) var artwork: DailyArtwork
    @Published private(set) var phase: ArtworkPhase = .pristine
    @Published var selectedColorIndex: Int = 0

    /// col/row → palette index for every filled cell
    @Published private(set) var filledCells: [GridCell: Int] = [:] {
        didSet {
            persistProgress()
            checkCompletion()
        }
    }

    @Published var debugDayOffset: Int = 0 {
        didSet { reloadForCurrentDay() }
    }

    @Published var handoffPhase: HandoffPhase = .idle
    @Published var globalCount: Int = 0

    enum HandoffPhase: Equatable {
        case idle, fadingOut, fadingIn
    }

    // MARK: - Derived

    var isComplete: Bool {
        filledCells.count >= artwork.fillableCellCount && artwork.fillableCellCount > 0
    }

    var progressFraction: Double {
        guard artwork.fillableCellCount > 0 else { return 0 }
        return Double(filledCells.count) / Double(artwork.fillableCellCount)
    }

    var progressText: String {
        "\(filledCells.count) / \(artwork.fillableCellCount)"
    }

    // MARK: - Private

    private var currentDayID: String
    private var midnightTimer: AnyCancellable?
    private var tomorrowArtwork: DailyArtwork?
    private var countPollTask: Task<Void, Never>?
    private var didReportCompletion = false

    // MARK: - Init

    init() {
        let dayID = Self.dayString(offsetDays: 0)
        let a = Self.loadArtwork(dayID: dayID)
        self.artwork = a
        self.currentDayID = dayID
        self.filledCells = Self.loadProgress(for: a.id)
        self.didReportCompletion = Self.loadDidReport(for: dayID)

        // Restore phase if already in progress
        if !filledCells.isEmpty { phase = .painting }

        startMidnightTimer()
        preCacheTomorrow()

        if isComplete {
            phase = .complete
            Task { await fetchCurrentCount() }
        }
    }

    // MARK: - Phase Actions

    func beginPainting() {
        guard phase == .pristine else { return }
        phase = .painting
    }

    // MARK: - Fill

    enum FillResult { case filled, wrongColor, nonInteractive, alreadyFilled }

    @discardableResult
    func tryFill(col: Int, row: Int) -> FillResult {
        let colorIdx = artwork.colorIndex(col: col, row: row)

        if artwork.isNonInteractive(colorIdx) { return .nonInteractive }

        let cell = GridCell(col: col, row: row)
        if filledCells[cell] != nil { return .alreadyFilled }

        guard selectedColorIndex == colorIdx else { return .wrongColor }

        filledCells[cell] = colorIdx
        return .filled
    }

    func resetThisDayProgress() {
        filledCells = [:]
        phase = .pristine
        didReportCompletion = false
        globalCount = 0
        stopPolling()
        Self.clearDidReport(for: currentDayID)
        Self.clearProgress(for: currentDayID)
    }

    // MARK: - Completion

    private func checkCompletion() {
        guard isComplete, !didReportCompletion else { return }
        didReportCompletion = true
        Self.saveDidReport(for: currentDayID)

        withAnimation { phase = .complete }

        Task {
            let count = await OneHueAPI.incrementCount(for: currentDayID)
            globalCount = count
            startPolling()
        }
    }

    private func fetchCurrentCount() async {
        globalCount = await OneHueAPI.fetchCount(for: currentDayID)
    }

    private func startPolling() {
        stopPolling()
        countPollTask = OneHueAPI.pollCount(for: currentDayID, interval: 15) { [weak self] c in
            self?.globalCount = c
        }
    }

    private func stopPolling() {
        countPollTask?.cancel()
        countPollTask = nil
    }

    // MARK: - Debug helpers

    func debugPrevDay()     { debugDayOffset -= 1 }
    func debugNextDay()     { debugDayOffset += 1 }
    func debugBackToToday() { debugDayOffset = 0 }

    /// Force all cells filled — useful for testing completion screen
    func debugForceComplete() {
        var cells: [GridCell: Int] = [:]
        for row in 0..<artwork.rows {
            for col in 0..<artwork.cols {
                let idx = artwork.colorIndex(col: col, row: row)
                if !artwork.isNonInteractive(idx) {
                    cells[GridCell(col: col, row: row)] = idx
                }
            }
        }
        filledCells = cells
        phase = .complete
    }

    // MARK: - Scene Phase

    func onForeground() {
        checkForNewDay()
        if isComplete { Task { await fetchCurrentCount() } }
    }

    // MARK: - Midnight Handoff

    private func startMidnightTimer() {
        midnightTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkForNewDay() }
    }

    private func checkForNewDay() {
        let todayID = Self.dayString(offsetDays: debugDayOffset)
        guard todayID != currentDayID else { return }
        performHandoff(to: todayID)
    }

    private func performHandoff(to newDayID: String) {
        guard handoffPhase == .idle else { return }
        stopPolling()

        withAnimation(.easeOut(duration: 0.6)) { handoffPhase = .fadingOut }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self else { return }
            let newArtwork: DailyArtwork
            if let cached = tomorrowArtwork, cached.id == newDayID {
                newArtwork = cached; tomorrowArtwork = nil
            } else {
                newArtwork = Self.loadArtwork(dayID: newDayID)
            }
            artwork = newArtwork
            currentDayID = newDayID
            selectedColorIndex = 0
            filledCells = Self.loadProgress(for: newArtwork.id)
            didReportCompletion = Self.loadDidReport(for: newDayID)
            globalCount = 0
            phase = filledCells.isEmpty ? .pristine : .painting

            withAnimation(.easeIn(duration: 0.6)) { self.handoffPhase = .fadingIn }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                self.handoffPhase = .idle
                self.preCacheTomorrow()
            }
        }
    }

    private func preCacheTomorrow() {
        let tomorrowID = Self.dayString(offsetDays: debugDayOffset + 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.tomorrowArtwork = Self.loadArtwork(dayID: tomorrowID)
        }
    }

    private func reloadForCurrentDay() {
        stopPolling()
        let dayID = Self.dayString(offsetDays: debugDayOffset)
        let newArtwork = Self.loadArtwork(dayID: dayID)
        artwork = newArtwork
        currentDayID = dayID
        selectedColorIndex = 0
        filledCells = Self.loadProgress(for: newArtwork.id)
        didReportCompletion = Self.loadDidReport(for: dayID)
        globalCount = 0
        phase = filledCells.isEmpty ? .pristine : .painting
        tomorrowArtwork = nil
        preCacheTomorrow()
    }

    // MARK: - Loading

    private static func loadArtwork(dayID: String) -> DailyArtwork {
        if let a = GridArtworkLoader.load(dayID: dayID) { return a }
        return GridArtworkLoader.makeMock(dayID: dayID)
    }

    // MARK: - Persistence

    private func persistProgress() {
        // Encode as flat array of [col, row, colorIndex] triples
        let flat: [Int] = filledCells.flatMap { cell, idx in
            [cell.col, cell.row, idx]
        }
        UserDefaults.standard.set(flat, forKey: Self.progressKey(for: artwork.id))
    }

    private static func loadProgress(for dayID: String) -> [GridCell: Int] {
        let flat = UserDefaults.standard.array(forKey: progressKey(for: dayID)) as? [Int] ?? []
        var result: [GridCell: Int] = [:]
        var i = 0
        while i + 2 < flat.count {
            result[GridCell(col: flat[i], row: flat[i+1])] = flat[i+2]
            i += 3
        }
        return result
    }

    private static func clearProgress(for dayID: String) {
        UserDefaults.standard.removeObject(forKey: progressKey(for: dayID))
    }

    private static func progressKey(for dayID: String) -> String { "onehue.grid.\(dayID)" }

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
        let cal  = Calendar(identifier: .gregorian)
        let base = cal.startOfDay(for: Date())
        let date = cal.date(byAdding: .day, value: offsetDays, to: base) ?? base
        let f    = DateFormatter()
        f.calendar = cal
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
