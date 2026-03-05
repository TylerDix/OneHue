import Foundation
import SwiftUI

/// Parses SVG files exported from Adobe Illustrator into `DailyArtwork` models.
///
/// Each SVG element (`<path>`, `<rect>`, `<circle>`, `<ellipse>`, `<polygon>`)
/// with a fill color becomes a colorable `Region`. The parser builds a color palette
/// from the fill colors found in the SVG.
///
/// Supports fills defined via:
/// - Inline `fill` attribute
/// - Inline `style` attribute
/// - CSS `<style>` block with class selectors (Illustrator default)
/// - Inherited fill from parent `<g>` elements
///
/// Usage:
/// ```swift
/// let artwork = try SVGDocumentParser.parse(
///     svgNamed: "day_001_peace",
///     title: "Peace",
///     subject: "peace symbol",
///     completionMessage: "Today, [count] people traced the oldest wish..."
/// )
/// ```
final class SVGDocumentParser: NSObject, XMLParserDelegate {

    // MARK: - Public API

    /// Parse an SVG from the app bundle.
    static func parse(
        svgNamed name: String,
        id: String? = nil,
        title: String = "Today",
        subject: String = "",
        completionMessage: String = ""
    ) throws -> DailyArtwork {
        guard let url = Bundle.main.url(forResource: name, withExtension: "svg") else {
            throw OneHueError.fileNotFound("\(name).svg")
        }
        let data = try Data(contentsOf: url)
        return try parse(svgData: data, id: id ?? name, title: title,
                         subject: subject, completionMessage: completionMessage)
    }

    /// Parse raw SVG data.
    static func parse(
        svgData data: Data,
        id: String,
        title: String,
        subject: String,
        completionMessage: String
    ) throws -> DailyArtwork {
        let parser = SVGDocumentParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser

        guard xmlParser.parse() else {
            throw parser.error ?? OneHueError.parseFailed("Unknown XML error")
        }

        guard !parser.rawRegions.isEmpty else {
            throw OneHueError.noRegions
        }

        // Coordinate space
        let vw = parser.viewBoxW > 0 ? parser.viewBoxW : parser.svgWidth
        let vh = parser.viewBoxH > 0 ? parser.viewBoxH : parser.svgHeight
        guard vw > 0, vh > 0 else {
            throw OneHueError.parseFailed("SVG has no viewBox or width/height")
        }

        // Filter out background regions (paths covering nearly the full canvas)
        let filteredRaw = parser.rawRegions.filter { raw in
            let path = SVGPathParser.path(from: raw.pathData)
            let finalPath: Path
            if let t = raw.transform {
                finalPath = path.applying(t)
            } else {
                finalPath = path
            }
            let bounds = finalPath.boundingRect
            let coverageW = bounds.width / vw
            let coverageH = bounds.height / vh
            // Skip if this path covers more than 90% of the canvas in both dimensions
            return !(coverageW > 0.9 && coverageH > 0.9)
        }

        // Rebuild palette from only the colors used in filtered regions
        let usedHexes = Set(filteredRaw.map { $0.fillHex })
        let filteredColors = parser.colorOrder.filter { usedHexes.contains($0) }
        let palette: [Color] = filteredColors.map { Color(hex: $0) }

        var hexToIndex: [String: Int] = [:]
        for (i, hex) in filteredColors.enumerated() {
            hexToIndex[hex] = i
        }

        let regions: [Region] = filteredRaw.enumerated().map { idx, raw in
            let originalPath = SVGPathParser.path(from: raw.pathData)

            // Apply transform first if present, then normalize
            let toNormalize: Path
            if let t = raw.transform {
                toNormalize = originalPath.applying(t)
            } else {
                toNormalize = originalPath
            }

            let normalized = toNormalize.applying(
                CGAffineTransform(scaleX: 1.0 / vw, y: 1.0 / vh)
            )

            let colorIdx = hexToIndex[raw.fillHex] ?? 0

            return Region(
                id: idx,
                number: colorIdx + 1,
                colorIndex: colorIdx,
                path: normalized
            )
        }

        return DailyArtwork(
            id: id,
            title: title,
            subject: subject,
            completionMessage: completionMessage,
            palette: palette,
            regions: regions,
            viewBoxWidth: vw,
            viewBoxHeight: vh
        )
    }

    // MARK: - Internal State

    private struct RawRegion {
        let pathData: String
        let fillHex: String
        let transform: CGAffineTransform?
    }

    private var rawRegions: [RawRegion] = []
    private var colorOrder: [String] = []
    private var colorSet: Set<String> = []
    private var viewBoxW: CGFloat = 0
    private var viewBoxH: CGFloat = 0
    private var svgWidth: CGFloat = 0
    private var svgHeight: CGFloat = 0
    private var error: Error?

    // CSS class → fill color map (parsed from <style> block)
    private var classToFill: [String: String] = [:]
    private var styleContent = ""
    private var insideStyle = false

    // Track nested <g> transforms and styles
    private var groupFillStack: [String?] = []

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement el: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attrs: [String: String]) {

        switch el.lowercased() {
        case "svg":
            parseSVGElement(attrs)

        case "style":
            insideStyle = true
            styleContent = ""

        case "g":
            let fill = extractFill(from: attrs)
            groupFillStack.append(fill)

        case "path":
            guard let d = attrs["d"], !d.isEmpty else { return }
            if let fill = resolveFill(attrs), fill != "none" {
                let t = parseTransform(attrs["transform"])
                addRegion(pathData: d, fillHex: normalizeHex(fill), transform: t)
            }

        case "rect":
            if let fill = resolveFill(attrs), fill != "none" {
                let x = cgFloat(attrs["x"]) ?? 0
                let y = cgFloat(attrs["y"]) ?? 0
                guard let w = cgFloat(attrs["width"]), let h = cgFloat(attrs["height"]) else { return }
                let rx = cgFloat(attrs["rx"]) ?? 0
                let ry = cgFloat(attrs["ry"]) ?? 0
                let d = SVGPathParser.rectToPathData(x: x, y: y, w: w, h: h, rx: rx, ry: ry)
                let t = parseTransform(attrs["transform"])
                addRegion(pathData: d, fillHex: normalizeHex(fill), transform: t)
            }

        case "circle":
            if let fill = resolveFill(attrs), fill != "none",
               let cx = cgFloat(attrs["cx"]), let cy = cgFloat(attrs["cy"]),
               let r = cgFloat(attrs["r"]) {
                let d = SVGPathParser.circleToPathData(cx: cx, cy: cy, r: r)
                let t = parseTransform(attrs["transform"])
                addRegion(pathData: d, fillHex: normalizeHex(fill), transform: t)
            }

        case "ellipse":
            if let fill = resolveFill(attrs), fill != "none",
               let cx = cgFloat(attrs["cx"]), let cy = cgFloat(attrs["cy"]),
               let rx = cgFloat(attrs["rx"]), let ry = cgFloat(attrs["ry"]) {
                let d = SVGPathParser.ellipseToPathData(cx: cx, cy: cy, rx: rx, ry: ry)
                let t = parseTransform(attrs["transform"])
                addRegion(pathData: d, fillHex: normalizeHex(fill), transform: t)
            }

        case "polygon":
            if let fill = resolveFill(attrs), fill != "none",
               let points = attrs["points"] {
                let d = SVGPathParser.polygonToPathData(points: points)
                if !d.isEmpty {
                    let t = parseTransform(attrs["transform"])
                    addRegion(pathData: d, fillHex: normalizeHex(fill), transform: t)
                }
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement el: String,
                namespaceURI: String?, qualifiedName: String?) {
        if el.lowercased() == "g" {
            _ = groupFillStack.popLast()
        }
        if el.lowercased() == "style" {
            insideStyle = false
            // Parse CSS immediately so class lookups work for subsequent elements
            parseCSSStyles()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideStyle {
            styleContent += string
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred err: Error) {
        error = OneHueError.parseFailed(err.localizedDescription)
    }

    // MARK: - CSS Style Parsing

    /// Parse the accumulated CSS from the <style> block.
    /// Extracts `.className { fill: #hex; }` patterns.
    private func parseCSSStyles() {
        guard !styleContent.isEmpty else { return }

        // Match patterns like: .st0 { fill: #f8f8ee; }
        // Also handles multiline and extra whitespace
        let stripped = styleContent
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        // Split on "}" to get each rule block
        let blocks = stripped.components(separatedBy: "}")
        for block in blocks {
            let parts = block.components(separatedBy: "{")
            guard parts.count == 2 else { continue }

            let selector = parts[0].trimmingCharacters(in: .whitespaces)
            let body = parts[1]

            // Extract class name (e.g. ".st0" → "st0")
            guard selector.hasPrefix(".") else { continue }
            let className = String(selector.dropFirst())

            // Extract fill from the body
            if let fill = extractFillFromStyle(body) {
                classToFill[className] = fill
            }
        }
    }

    // MARK: - Fill Resolution

    private func parseSVGElement(_ attrs: [String: String]) {
        if let vb = attrs["viewBox"] ?? attrs["viewbox"] {
            let parts = vb.split(separator: " ").compactMap { Double($0) }
            if parts.count == 4 {
                viewBoxW = CGFloat(parts[2])
                viewBoxH = CGFloat(parts[3])
            }
        }
        if let w = cgFloat(attrs["width"])  { svgWidth = w }
        if let h = cgFloat(attrs["height"]) { svgHeight = h }
    }

    /// Resolve fill color: explicit fill > inline style > CSS class > parent group > default black
    private func resolveFill(_ attrs: [String: String]) -> String? {
        // 1. Explicit fill attribute
        if let fill = attrs["fill"] { return fill }

        // 2. Inline style
        if let style = attrs["style"], let fill = extractFillFromStyle(style) {
            return fill
        }

        // 3. CSS class
        if let cls = attrs["class"] {
            // Handle multiple classes (e.g. "st0 st1") — use first match
            for className in cls.split(separator: " ") {
                if let fill = classToFill[String(className)] {
                    return fill
                }
            }
        }

        // 4. Inherited from parent <g>
        for fill in groupFillStack.reversed() {
            if let f = fill { return f }
        }

        // 5. SVG default is black
        return "#000000"
    }

    private func extractFill(from attrs: [String: String]) -> String? {
        if let fill = attrs["fill"] { return fill }
        if let style = attrs["style"] { return extractFillFromStyle(style) }
        if let cls = attrs["class"] {
            for className in cls.split(separator: " ") {
                if let fill = classToFill[String(className)] {
                    return fill
                }
            }
        }
        return nil
    }

    private func extractFillFromStyle(_ style: String) -> String? {
        for part in style.components(separatedBy: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("fill:") {
                return trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func addRegion(pathData: String, fillHex: String, transform: CGAffineTransform? = nil) {
        rawRegions.append(RawRegion(pathData: pathData, fillHex: fillHex, transform: transform))
        if !colorSet.contains(fillHex) {
            colorSet.insert(fillHex)
            colorOrder.append(fillHex)
        }
    }

    // MARK: - Transform Parsing

    /// Parse SVG `transform` attribute. Supports translate, rotate, scale, matrix.
    private func parseTransform(_ str: String?) -> CGAffineTransform? {
        guard let str = str, !str.isEmpty else { return nil }

        var result = CGAffineTransform.identity
        var s = str

        while !s.isEmpty {
            s = s.trimmingCharacters(in: .whitespaces)

            if s.hasPrefix("translate(") {
                let (vals, rest) = extractArgs(from: s, prefix: "translate(")
                if vals.count >= 2 {
                    result = result.translatedBy(x: vals[0], y: vals[1])
                } else if vals.count == 1 {
                    result = result.translatedBy(x: vals[0], y: 0)
                }
                s = rest

            } else if s.hasPrefix("rotate(") {
                let (vals, rest) = extractArgs(from: s, prefix: "rotate(")
                if vals.count == 3 {
                    // rotate(angle, cx, cy)
                    let angle = vals[0] * .pi / 180
                    result = result.translatedBy(x: vals[1], y: vals[2])
                    result = result.rotated(by: angle)
                    result = result.translatedBy(x: -vals[1], y: -vals[2])
                } else if vals.count >= 1 {
                    result = result.rotated(by: vals[0] * .pi / 180)
                }
                s = rest

            } else if s.hasPrefix("scale(") {
                let (vals, rest) = extractArgs(from: s, prefix: "scale(")
                if vals.count >= 2 {
                    result = result.scaledBy(x: vals[0], y: vals[1])
                } else if vals.count == 1 {
                    result = result.scaledBy(x: vals[0], y: vals[0])
                }
                s = rest

            } else if s.hasPrefix("matrix(") {
                let (vals, rest) = extractArgs(from: s, prefix: "matrix(")
                if vals.count == 6 {
                    let m = CGAffineTransform(a: vals[0], b: vals[1], c: vals[2],
                                              d: vals[3], tx: vals[4], ty: vals[5])
                    result = result.concatenating(m)
                }
                s = rest

            } else {
                // Skip unknown content
                break
            }
        }

        return result == .identity ? nil : result
    }

    /// Extract numeric arguments from a transform function like "translate(10, 20) ..."
    /// Returns the values and the remaining string after the closing ")".
    private func extractArgs(from str: String, prefix: String) -> ([CGFloat], String) {
        guard str.hasPrefix(prefix) else { return ([], str) }
        let after = String(str.dropFirst(prefix.count))
        guard let closeIdx = after.firstIndex(of: ")") else { return ([], str) }

        let inner = String(after[after.startIndex..<closeIdx])
        let rest = String(after[after.index(after: closeIdx)...])

        let vals = inner
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .compactMap { Double($0) }
            .map { CGFloat($0) }

        return (vals, rest)
    }

    // MARK: - Helpers

    private func normalizeHex(_ fill: String) -> String {
        let trimmed = fill.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#") {
            let hex = trimmed.uppercased()
            if hex.count == 4 {
                let chars = Array(hex.dropFirst())
                return "#\(chars[0])\(chars[0])\(chars[1])\(chars[1])\(chars[2])\(chars[2])"
            }
            return hex
        }

        if trimmed.lowercased().hasPrefix("rgb(") {
            let inner = trimmed
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let parts = inner.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 3 {
                return String(format: "#%02X%02X%02X", parts[0], parts[1], parts[2])
            }
        }

        let named: [String: String] = [
            "black": "#000000", "white": "#FFFFFF", "red": "#FF0000",
            "green": "#008000", "blue": "#0000FF", "yellow": "#FFFF00",
            "orange": "#FFA500", "purple": "#800080", "pink": "#FFC0CB",
            "gray": "#808080", "grey": "#808080", "none": "none"
        ]
        return named[trimmed.lowercased()] ?? "#000000"
    }

    private func cgFloat(_ str: String?) -> CGFloat? {
        guard let s = str else { return nil }
        let cleaned = s.replacingOccurrences(of: "px", with: "")
                       .replacingOccurrences(of: "pt", with: "")
        return Double(cleaned).map { CGFloat($0) }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Errors

enum OneHueError: LocalizedError {
    case fileNotFound(String)
    case parseFailed(String)
    case noRegions

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name): return "File not found: \(name)"
        case .parseFailed(let detail): return "Parse failed: \(detail)"
        case .noRegions: return "No colorable regions found in SVG"
        }
    }
}
