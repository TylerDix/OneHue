import SwiftUI
import Combine

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

    // MARK: - Init

    init() {
        let doc = SVGParser.parse(svgName: "GoldenFirefly")
              ?? SVGDocument.empty(id: "fallback")
        self.document = doc
        self.spatialHash = SpatialHash(viewBox: doc.viewBox, elements: doc.elements)
        self.filledElements = Self.loadProgress(for: doc.id)

        if filledElements.count >= doc.totalElements && doc.totalElements > 0 {
            phase = .complete
        }
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
        return .filled
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

    // MARK: - Completion

    private func checkCompletion() {
        guard isComplete, phase != .complete else { return }
        withAnimation { phase = .complete }
    }

    // MARK: - Debug

    func debugForceComplete() {
        var all = Set<Int>()
        for i in 0..<document.elements.count {
            all.insert(i)
        }
        filledElements = all
        phase = .complete
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
