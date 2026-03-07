import SwiftUI
import CoreGraphics

// MARK: - SVGElement

/// A single shape element parsed from an SVG file.
struct SVGElement: Identifiable {
    let id: Int               // 0-based index in parse order
    let className: String     // e.g. "st5"
    let path: CGPath          // resolved geometry
    let bounds: CGRect        // path.boundingBoxOfPath
    let centroid: CGPoint     // bounding-box center
}

// MARK: - SVGColorGroup

/// All elements sharing the same CSS class.
struct SVGColorGroup: Identifiable {
    let id: Int               // 0-based group index (display number = id + 1)
    let className: String     // e.g. "st5"
    let color: Color          // original SVG fill color
    let hexColor: String      // e.g. "#0a1111"
    let elementIndices: [Int] // indices into SVGDocument.elements
    let centroid: CGPoint     // average centroid of all elements
    let boundingBox: CGRect   // union of all element bounds
}

// MARK: - ElementCluster

/// A group of adjacent same-color elements treated as one logical region.
struct ElementCluster: Identifiable {
    let id: Int
    let groupIndex: Int
    let elementIndices: [Int]
    let bounds: CGRect
    let labelCenter: CGPoint      // centroid of largest element in cluster
}

// MARK: - SVGDocument

/// Fully parsed SVG ready for rendering and interaction.
struct SVGDocument: Identifiable {
    let id: String                    // filename stem, e.g. "house1"
    let title: String
    let viewBox: CGRect
    let elements: [SVGElement]
    let groups: [SVGColorGroup]
    let completionMessage: String

    /// Element index → group index lookup (built once)
    let elementGroupMap: [Int: Int]

    /// Clusters of adjacent same-group elements (one label per cluster)
    let clusters: [ElementCluster]
    /// Element index → cluster index lookup
    let elementClusterMap: [Int: Int]

    var aspectRatio: CGFloat {
        guard viewBox.height > 0 else { return 0.747 }
        return viewBox.width / viewBox.height
    }

    var totalElements: Int { elements.count }

    static func empty(id: String) -> SVGDocument {
        SVGDocument(
            id: id,
            title: "Loading…",
            viewBox: CGRect(x: 0, y: 0, width: 1792, height: 2400),
            elements: [],
            groups: [],
            completionMessage: "Complete!",
            elementGroupMap: [:],
            clusters: [],
            elementClusterMap: [:]
        )
    }
}

// MARK: - Spatial Hash for Hit Testing

/// Grid-based spatial index for fast point-in-path queries.
struct SpatialHash {
    private let cellSize: CGFloat
    private let cols: Int
    private let rows: Int
    private let origin: CGPoint
    private var buckets: [[Int]]  // each bucket holds element indices

    init(viewBox: CGRect, elements: [SVGElement], cellSize: CGFloat = 40) {
        self.cellSize = cellSize
        self.origin = viewBox.origin
        self.cols = max(1, Int(ceil(viewBox.width / cellSize)))
        self.rows = max(1, Int(ceil(viewBox.height / cellSize)))
        self.buckets = Array(repeating: [], count: cols * rows)

        for element in elements {
            let b = element.bounds
            let minCol = max(0, Int((b.minX - origin.x) / cellSize))
            let maxCol = min(cols - 1, Int((b.maxX - origin.x) / cellSize))
            let minRow = max(0, Int((b.minY - origin.y) / cellSize))
            let maxRow = min(rows - 1, Int((b.maxY - origin.y) / cellSize))

            for r in minRow...maxRow {
                for c in minCol...maxCol {
                    buckets[r * cols + c].append(element.id)
                }
            }
        }
    }

    /// Returns candidate element indices for a given SVG-space point.
    func candidates(at point: CGPoint) -> [Int] {
        let c = Int((point.x - origin.x) / cellSize)
        let r = Int((point.y - origin.y) / cellSize)
        guard c >= 0, c < cols, r >= 0, r < rows else { return [] }
        return buckets[r * cols + c]
    }
}
