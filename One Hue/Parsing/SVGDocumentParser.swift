import Foundation
import SwiftUI

/// Parses SVG files exported from Adobe Illustrator into `DailyArtwork` models.
///
/// Each named SVG element (`<path>`, `<rect>`, `<circle>`, `<ellipse>`, `<polygon>`)
/// with a fill color becomes a colorable `Region`. The parser automatically builds
/// a color palette from the fill colors found in the SVG.
///
/// Usage:
/// ```swift
/// let artwork = try SVGDocumentParser.parse(
///     svgNamed: "day_001",
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

        // Build palette from discovered fill colors
        let sortedColors = parser.colorOrder  // preserves discovery order
        let palette: [Color] = sortedColors.map { Color(hex: $0) }

        // Build a map: hex → palette index
        var hexToIndex: [String: Int] = [:]
        for (i, hex) in sortedColors.enumerated() {
            hexToIndex[hex] = i
        }

        // Normalize paths to 0...1 coordinate space
        let vw = parser.viewBoxW > 0 ? parser.viewBoxW : parser.svgWidth
        let vh = parser.viewBoxH > 0 ? parser.viewBoxH : parser.svgHeight
        guard vw > 0, vh > 0 else {
            throw OneHueError.parseFailed("SVG has no viewBox or width/height")
        }

        let regions: [Region] = parser.rawRegions.enumerated().map { idx, raw in
            // Parse the SVG path data into a SwiftUI Path
            let originalPath = SVGPathParser.path(from: raw.pathData)

            // Normalize to 0...1
            let normalized = originalPath.applying(
                CGAffineTransform(scaleX: 1.0 / vw, y: 1.0 / vh)
            )

            let colorIdx = hexToIndex[raw.fillHex] ?? 0

            return Region(
                id: idx,
                number: colorIdx + 1,  // 1-indexed display number
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
    }

    private var rawRegions: [RawRegion] = []
    private var colorOrder: [String] = []          // unique hex values in discovery order
    private var colorSet: Set<String> = []
    private var viewBoxW: CGFloat = 0
    private var viewBoxH: CGFloat = 0
    private var svgWidth: CGFloat = 0
    private var svgHeight: CGFloat = 0
    private var error: Error?

    // Track nested <g> transforms and styles
    private var groupFillStack: [String?] = []

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement el: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes attrs: [String: String]) {

        switch el.lowercased() {
        case "svg":
            parseSVGElement(attrs)

        case "g":
            let fill = extractFill(from: attrs)
            groupFillStack.append(fill)

        case "path":
            guard let d = attrs["d"], !d.isEmpty else { return }
            if let fill = resolveFill(attrs), fill != "none" {
                addRegion(pathData: d, fillHex: normalizeHex(fill))
            }

        case "rect":
            if let fill = resolveFill(attrs), fill != "none",
               let x = cgFloat(attrs["x"]), let y = cgFloat(attrs["y"]),
               let w = cgFloat(attrs["width"]), let h = cgFloat(attrs["height"]) {
                let rx = cgFloat(attrs["rx"]) ?? 0
                let ry = cgFloat(attrs["ry"]) ?? 0
                let d = SVGPathParser.rectToPathData(x: x, y: y, w: w, h: h, rx: rx, ry: ry)
                addRegion(pathData: d, fillHex: normalizeHex(fill))
            }

        case "circle":
            if let fill = resolveFill(attrs), fill != "none",
               let cx = cgFloat(attrs["cx"]), let cy = cgFloat(attrs["cy"]),
               let r = cgFloat(attrs["r"]) {
                let d = SVGPathParser.circleToPathData(cx: cx, cy: cy, r: r)
                addRegion(pathData: d, fillHex: normalizeHex(fill))
            }

        case "ellipse":
            if let fill = resolveFill(attrs), fill != "none",
               let cx = cgFloat(attrs["cx"]), let cy = cgFloat(attrs["cy"]),
               let rx = cgFloat(attrs["rx"]), let ry = cgFloat(attrs["ry"]) {
                let d = SVGPathParser.ellipseToPathData(cx: cx, cy: cy, rx: rx, ry: ry)
                addRegion(pathData: d, fillHex: normalizeHex(fill))
            }

        case "polygon":
            if let fill = resolveFill(attrs), fill != "none",
               let points = attrs["points"] {
                let d = SVGPathParser.polygonToPathData(points: points)
                if !d.isEmpty { addRegion(pathData: d, fillHex: normalizeHex(fill)) }
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
    }

    func parser(_ parser: XMLParser, parseErrorOccurred err: Error) {
        error = OneHueError.parseFailed(err.localizedDescription)
    }

    // MARK: - Helpers

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

    /// Resolve fill color: element attribute > inline style > parent group > default black
    private func resolveFill(_ attrs: [String: String]) -> String? {
        // 1. Explicit fill attribute
        if let fill = attrs["fill"] { return fill }

        // 2. Inline style
        if let style = attrs["style"], let fill = extractFillFromStyle(style) {
            return fill
        }

        // 3. Inherited from parent <g>
        for fill in groupFillStack.reversed() {
            if let f = fill { return f }
        }

        // 4. SVG default is black
        return "#000000"
    }

    private func extractFill(from attrs: [String: String]) -> String? {
        if let fill = attrs["fill"] { return fill }
        if let style = attrs["style"] { return extractFillFromStyle(style) }
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

    private func addRegion(pathData: String, fillHex: String) {
        rawRegions.append(RawRegion(pathData: pathData, fillHex: fillHex))
        if !colorSet.contains(fillHex) {
            colorSet.insert(fillHex)
            colorOrder.append(fillHex)
        }
    }

    private func normalizeHex(_ fill: String) -> String {
        let trimmed = fill.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("#") {
            let hex = trimmed.uppercased()
            // Expand shorthand #RGB → #RRGGBB
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

        // Named colors
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
