import Foundation
import SwiftUI
import CoreGraphics

/// Parses an SVG file from the app bundle into an SVGDocument.
final class SVGParser: NSObject, XMLParserDelegate {

    // MARK: - Public API

    static func parse(svgName: String) -> SVGDocument? {
        guard let url = Bundle.main.url(forResource: svgName, withExtension: "svg"),
              let data = try? Data(contentsOf: url) else {
            print("[SVGParser] Could not find \(svgName).svg in bundle")
            return nil
        }
        return parse(data: data, id: svgName)
    }

    static func parse(data: Data, id: String) -> SVGDocument? {
        let parser = SVGParser(id: id)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        guard xmlParser.parse() else {
            print("[SVGParser] XML parse failed: \(xmlParser.parserError?.localizedDescription ?? "unknown")")
            return nil
        }
        return parser.buildDocument()
    }

    // MARK: - Internal State

    private let documentID: String
    private var viewBox = CGRect(x: 0, y: 0, width: 1792, height: 2400)
    private var styleColors: [String: String] = [:]  // className → hex
    private var parsedElements: [(className: String, path: CGPath)] = []

    // XML state
    private var insideStyle = false
    private var styleText = ""
    private var insideDefs = false
    private var inlineStyleCounter = 0

    private init(id: String) {
        self.documentID = id
        super.init()
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {

        switch elementName {
        case "svg":
            if let vb = attributes["viewBox"] {
                viewBox = parseViewBox(vb)
            }

        case "defs":
            insideDefs = true

        case "style":
            if insideDefs {
                insideStyle = true
                styleText = ""
            }

        case "path":
            guard let cls = resolveClassName(from: attributes),
                  let d = attributes["d"] else { break }
            let cgPath = SVGPathParser.parse(d)
            let finalPath = applyTransform(attributes, to: cgPath)
            parsedElements.append((className: cls, path: finalPath))

        case "circle":
            guard let cls = resolveClassName(from: attributes),
                  let cxStr = attributes["cx"], let cx = Double(cxStr),
                  let cyStr = attributes["cy"], let cy = Double(cyStr),
                  let rStr = attributes["r"], let r = Double(rStr) else { break }
            let rect = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
            let cgPath = CGPath(ellipseIn: rect, transform: nil)
            let finalPath = applyTransform(attributes, to: cgPath)
            parsedElements.append((className: cls, path: finalPath))

        case "ellipse":
            guard let cls = resolveClassName(from: attributes) else { break }
            let cx = Double(attributes["cx"] ?? "0") ?? 0
            let cy = Double(attributes["cy"] ?? "0") ?? 0
            guard let rxStr = attributes["rx"], let rx = Double(rxStr), rx > 0,
                  let ryStr = attributes["ry"], let ry = Double(ryStr), ry > 0 else { break }
            let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
            let cgPath = CGPath(ellipseIn: rect, transform: nil)
            let finalPath = applyTransform(attributes, to: cgPath)
            parsedElements.append((className: cls, path: finalPath))

        case "polygon":
            guard let cls = resolveClassName(from: attributes),
                  let points = attributes["points"] else { break }
            if let cgPath = parsePolygon(points: points) {
                let finalPath = applyTransform(attributes, to: cgPath)
                parsedElements.append((className: cls, path: finalPath))
            }

        case "rect":
            guard let cls = resolveClassName(from: attributes),
                  let x = Double(attributes["x"] ?? "0"),
                  let y = Double(attributes["y"] ?? "0"),
                  let w = Double(attributes["width"] ?? "0"),
                  let h = Double(attributes["height"] ?? "0") else { break }
            let rect = CGRect(x: x, y: y, width: w, height: h)
            let cgPath = CGPath(rect: rect, transform: nil)
            let finalPath = applyTransform(attributes, to: cgPath)
            parsedElements.append((className: cls, path: finalPath))

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideStyle {
            styleText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "style":
            if insideStyle {
                insideStyle = false
                parseStyleBlock(styleText)
            }
        case "defs":
            insideDefs = false
        default:
            break
        }
    }

    // MARK: - Build Document

    private func buildDocument() -> SVGDocument {
        // Build elements
        var elements: [SVGElement] = []
        for (i, parsed) in parsedElements.enumerated() {
            let bounds = parsed.path.boundingBoxOfPath
            let centroid = CGPoint(x: bounds.midX, y: bounds.midY)
            elements.append(SVGElement(
                id: i,
                className: parsed.className,
                path: parsed.path,
                bounds: bounds,
                centroid: centroid
            ))
        }

        // Discover unique class names in order of first appearance
        var seenClasses: [String] = []
        for el in elements {
            if !seenClasses.contains(el.className) {
                seenClasses.append(el.className)
            }
        }

        // Build groups
        var groups: [SVGColorGroup] = []
        var elementGroupMap: [Int: Int] = [:]

        for (groupIdx, className) in seenClasses.enumerated() {
            let indices = elements.enumerated()
                .filter { $0.element.className == className }
                .map { $0.offset }

            let hex = styleColors[className] ?? "#888888"
            let color = Color(hex: hex)

            // Compute group centroid (average of element centroids)
            var sumX: CGFloat = 0, sumY: CGFloat = 0
            var unionRect: CGRect = .null
            for idx in indices {
                sumX += elements[idx].centroid.x
                sumY += elements[idx].centroid.y
                unionRect = unionRect.union(elements[idx].bounds)
            }
            let count = CGFloat(indices.count)
            let groupCentroid = count > 0
                ? CGPoint(x: sumX / count, y: sumY / count)
                : CGPoint.zero

            groups.append(SVGColorGroup(
                id: groupIdx,
                className: className,
                color: color,
                hexColor: hex,
                elementIndices: indices,
                centroid: groupCentroid,
                boundingBox: unionRect
            ))

            for idx in indices {
                elementGroupMap[idx] = groupIdx
            }
        }

        // Build clusters of adjacent same-group elements
        let (clusters, elementClusterMap) = Self.buildClusters(
            elements: elements, groups: groups
        )

        // Title from filename
        let title = documentID
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized

        return SVGDocument(
            id: documentID,
            title: title,
            viewBox: viewBox,
            elements: elements,
            groups: groups,
            completionMessage: "Every shape found its color.",
            elementGroupMap: elementGroupMap,
            clusters: clusters,
            elementClusterMap: elementClusterMap
        )
    }

    // MARK: - Clustering

    /// Merge adjacent same-group elements into clusters using union-find.
    /// Elements whose bounding boxes are within `margin` SVG units get clustered.
    private static func buildClusters(
        elements: [SVGElement],
        groups: [SVGColorGroup]
    ) -> ([ElementCluster], [Int: Int]) {
        var clusters: [ElementCluster] = []
        var elementClusterMap: [Int: Int] = [:]
        var nextId = 0
        let margin: CGFloat = 3.0

        for group in groups {
            let indices = group.elementIndices
            guard !indices.isEmpty else { continue }

            // Union-find with path compression
            var parent: [Int: Int] = [:]
            for idx in indices { parent[idx] = idx }

            func find(_ x: Int) -> Int {
                var root = x
                while parent[root]! != root { root = parent[root]! }
                var curr = x
                while curr != root {
                    let next = parent[curr]!
                    parent[curr] = root
                    curr = next
                }
                return root
            }

            func union(_ a: Int, _ b: Int) {
                let ra = find(a), rb = find(b)
                if ra != rb { parent[ra] = rb }
            }

            // Connect elements whose expanded bounding boxes intersect
            for i in 0..<indices.count {
                let expanded = elements[indices[i]].bounds.insetBy(dx: -margin, dy: -margin)
                for j in (i + 1)..<indices.count {
                    if expanded.intersects(elements[indices[j]].bounds) {
                        union(indices[i], indices[j])
                    }
                }
            }

            // Collect connected components
            var components: [Int: [Int]] = [:]
            for idx in indices {
                components[find(idx), default: []].append(idx)
            }

            for (_, memberIndices) in components {
                var unionBounds = CGRect.null
                var largestArea: CGFloat = 0
                var largestIdx = memberIndices[0]

                for idx in memberIndices {
                    let el = elements[idx]
                    unionBounds = unionBounds.union(el.bounds)
                    let area = el.bounds.width * el.bounds.height
                    if area > largestArea {
                        largestArea = area
                        largestIdx = idx
                    }
                }

                clusters.append(ElementCluster(
                    id: nextId,
                    groupIndex: group.id,
                    elementIndices: memberIndices,
                    bounds: unionBounds,
                    labelCenter: elements[largestIdx].centroid
                ))

                for idx in memberIndices {
                    elementClusterMap[idx] = nextId
                }
                nextId += 1
            }
        }

        return (clusters, elementClusterMap)
    }

    // MARK: - Style Parsing

    private func parseStyleBlock(_ css: String) {
        // Match class rules containing a fill: property (supports multi-property rules)
        let pattern = #"\.([a-zA-Z_][a-zA-Z0-9_-]*)\s*\{[^}]*?fill:\s*(#[0-9a-fA-F]{3,8})[^}]*\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(css.startIndex..., in: css)

        regex.enumerateMatches(in: css, range: range) { match, _, _ in
            guard let match,
                  let classRange = Range(match.range(at: 1), in: css),
                  let colorRange = Range(match.range(at: 2), in: css) else { return }
            let className = String(css[classRange])
            let hexColor = String(css[colorRange])
            styleColors[className] = hexColor
        }
    }

    // MARK: - Class / Color Resolution

    /// Resolves a class name from element attributes, supporting CSS classes,
    /// inline `style="fill:#hex"`, and direct `fill="#hex"` attributes.
    private func resolveClassName(from attributes: [String: String]) -> String? {
        // Priority 1: inline style attribute with fill
        if let style = attributes["style"] {
            let fillPattern = #"fill:\s*(#[0-9a-fA-F]{3,8})"#
            if let regex = try? NSRegularExpression(pattern: fillPattern),
               let match = regex.firstMatch(in: style, range: NSRange(style.startIndex..., in: style)),
               let hexRange = Range(match.range(at: 1), in: style) {
                let hex = String(style[hexRange])
                let syntheticClass = "_inline_\(inlineStyleCounter)"
                inlineStyleCounter += 1
                styleColors[syntheticClass] = hex
                return syntheticClass
            }
        }

        // Priority 2: CSS class
        if let cls = attributes["class"] {
            // Also check for direct fill attribute as fallback if class has no CSS color
            if styleColors[cls] == nil, let fillHex = attributes["fill"] {
                styleColors[cls] = fillHex
            }
            return cls
        }

        // Priority 3: direct fill attribute
        if let fillHex = attributes["fill"], fillHex.hasPrefix("#") {
            let syntheticClass = "_fill_\(inlineStyleCounter)"
            inlineStyleCounter += 1
            styleColors[syntheticClass] = fillHex
            return syntheticClass
        }

        return nil
    }

    /// Applies a transform attribute (if present) to a CGPath.
    private func applyTransform(_ attributes: [String: String], to cgPath: CGPath) -> CGPath {
        guard let transformStr = attributes["transform"] else { return cgPath }
        var t = parseTransform(transformStr)
        return cgPath.copy(using: &t) ?? cgPath
    }

    // MARK: - Geometry Helpers

    private func parseViewBox(_ vb: String) -> CGRect {
        let parts = vb.split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .compactMap { Double($0) }
        guard parts.count == 4 else { return CGRect(x: 0, y: 0, width: 1792, height: 2400) }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    private func parsePolygon(points: String) -> CGPath? {
        let nums = points.split(whereSeparator: { $0.isWhitespace || $0 == "," })
            .compactMap { Double($0) }
        guard nums.count >= 4 else { return nil }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: nums[0], y: nums[1]))
        var i = 2
        while i + 1 < nums.count {
            path.addLine(to: CGPoint(x: nums[i], y: nums[i + 1]))
            i += 2
        }
        path.closeSubpath()
        return path
    }

    private func parseTransform(_ str: String) -> CGAffineTransform {
        var result = CGAffineTransform.identity
        // Match all transform functions left-to-right: name(params)
        let pattern = #"(translate|rotate|scale|matrix|skewX|skewY)\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let range = NSRange(str.startIndex..., in: str)

        regex.enumerateMatches(in: str, range: range) { match, _, _ in
            guard let match,
                  let nameRange = Range(match.range(at: 1), in: str),
                  let paramsRange = Range(match.range(at: 2), in: str) else { return }
            let name = String(str[nameRange])
            let nums = String(str[paramsRange])
                .split(whereSeparator: { $0.isWhitespace || $0 == "," })
                .compactMap { Double($0) }

            switch name {
            case "translate":
                let tx = nums.count >= 1 ? nums[0] : 0
                let ty = nums.count >= 2 ? nums[1] : 0
                result = result.concatenating(
                    CGAffineTransform(translationX: tx, y: ty)
                )

            case "rotate":
                guard let degrees = nums.first else { break }
                let radians = degrees * .pi / 180
                if nums.count >= 3 {
                    let cx = nums[1], cy = nums[2]
                    var r = CGAffineTransform(translationX: cx, y: cy)
                    r = r.rotated(by: radians)
                    r = r.translatedBy(x: -cx, y: -cy)
                    result = result.concatenating(r)
                } else {
                    result = result.concatenating(
                        CGAffineTransform(rotationAngle: radians)
                    )
                }

            case "scale":
                let sx = nums.count >= 1 ? nums[0] : 1
                let sy = nums.count >= 2 ? nums[1] : sx
                result = result.concatenating(
                    CGAffineTransform(scaleX: sx, y: sy)
                )

            case "matrix":
                guard nums.count >= 6 else { break }
                result = result.concatenating(
                    CGAffineTransform(a: nums[0], b: nums[1],
                                      c: nums[2], d: nums[3],
                                      tx: nums[4], ty: nums[5])
                )

            case "skewX":
                guard let degrees = nums.first else { break }
                let radians = degrees * .pi / 180
                result = result.concatenating(
                    CGAffineTransform(a: 1, b: 0, c: tan(radians), d: 1, tx: 0, ty: 0)
                )

            case "skewY":
                guard let degrees = nums.first else { break }
                let radians = degrees * .pi / 180
                result = result.concatenating(
                    CGAffineTransform(a: 1, b: tan(radians), c: 0, d: 1, tx: 0, ty: 0)
                )

            default:
                break
            }
        }
        return result
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        // Expand 3-digit shorthand: "abc" → "aabbcc"
        if cleaned.count == 3 {
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        }
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double(rgb         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
