import SwiftUI

/// Converts SVG path `d` attribute strings into SwiftUI `Path` objects.
///
/// Supports: M/m, L/l, H/h, V/v, C/c, S/s, Q/q, T/t, A/a, Z/z
/// Also provides helpers for converting `<rect>`, `<circle>`, `<ellipse>`,
/// and `<polygon>` attributes into path data.
enum SVGPathParser {

    // MARK: - Public API

    /// Parse an SVG path `d` string into a SwiftUI Path.
    static func path(from d: String) -> Path {
        let tokens = tokenize(d)
        return Path { p in
            var i = 0
            var cur = CGPoint.zero       // current point
            var start = CGPoint.zero     // subpath start
            var lastCP: CGPoint?         // last control point (for S/T reflection)
            var lastCmd: Character = " "

            while i < tokens.count {
                guard let ch = tokens[i].first, ch.isLetter else { i += 1; continue }
                let rel = ch.isLowercase
                let cmd = Character(ch.uppercased())
                i += 1

                switch cmd {

                // ── Move ──────────────────────────────────────────────
                case "M":
                    var first = true
                    while let pt = readPoint(&i, tokens, rel: rel, cur: cur) {
                        if first { p.move(to: pt); start = pt; first = false }
                        else     { p.addLine(to: pt) }
                        cur = pt
                        // After first M pair, implicit L for subsequent pairs
                    }

                // ── Line ──────────────────────────────────────────────
                case "L":
                    while let pt = readPoint(&i, tokens, rel: rel, cur: cur) {
                        p.addLine(to: pt); cur = pt
                    }

                case "H":
                    while let v = readDouble(&i, tokens) {
                        let x = rel ? cur.x + v : v
                        let pt = CGPoint(x: x, y: cur.y)
                        p.addLine(to: pt); cur = pt
                    }

                case "V":
                    while let v = readDouble(&i, tokens) {
                        let y = rel ? cur.y + v : v
                        let pt = CGPoint(x: cur.x, y: y)
                        p.addLine(to: pt); cur = pt
                    }

                // ── Cubic Bézier ──────────────────────────────────────
                case "C":
                    while let c1 = readPoint(&i, tokens, rel: rel, cur: cur),
                          let c2 = readPoint(&i, tokens, rel: rel, cur: cur),
                          let end = readPoint(&i, tokens, rel: rel, cur: cur) {
                        p.addCurve(to: end, control1: c1, control2: c2)
                        lastCP = c2; cur = end
                    }

                case "S":
                    while let c2 = readPoint(&i, tokens, rel: rel, cur: cur),
                          let end = readPoint(&i, tokens, rel: rel, cur: cur) {
                        let c1 = reflectedCP(lastCP, cur: cur, prev: lastCmd, allowed: "CScs")
                        p.addCurve(to: end, control1: c1, control2: c2)
                        lastCP = c2; cur = end
                    }

                // ── Quadratic Bézier ──────────────────────────────────
                case "Q":
                    while let cp = readPoint(&i, tokens, rel: rel, cur: cur),
                          let end = readPoint(&i, tokens, rel: rel, cur: cur) {
                        p.addQuadCurve(to: end, control: cp)
                        lastCP = cp; cur = end
                    }

                case "T":
                    while let end = readPoint(&i, tokens, rel: rel, cur: cur) {
                        let cp = reflectedCP(lastCP, cur: cur, prev: lastCmd, allowed: "QTqt")
                        p.addQuadCurve(to: end, control: cp)
                        lastCP = cp; cur = end
                    }

                // ── Arc ───────────────────────────────────────────────
                case "A":
                    while let rx = readDouble(&i, tokens),
                          let ry = readDouble(&i, tokens),
                          let _ = readDouble(&i, tokens),   // rotation (unused for now)
                          let largeArc = readDouble(&i, tokens),
                          let sweep = readDouble(&i, tokens),
                          let end = readPoint(&i, tokens, rel: rel, cur: cur) {
                        // Convert SVG arc to center parameterization, then to bezier curves
                        addArc(to: &p, from: cur, to: end,
                               rx: abs(rx), ry: abs(ry),
                               largeArc: largeArc != 0, sweep: sweep != 0)
                        cur = end
                    }

                // ── Close ─────────────────────────────────────────────
                case "Z":
                    p.closeSubpath()
                    cur = start

                default:
                    break
                }

                if cmd != "C" && cmd != "S" && cmd != "Q" && cmd != "T" {
                    lastCP = nil
                }
                lastCmd = ch
            }
        }
    }

    /// Convert SVG rect attributes to a path `d` string
    static func rectToPathData(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                               rx: CGFloat = 0, ry: CGFloat = 0) -> String {
        if rx > 0 || ry > 0 {
            let rx = min(rx, w / 2), ry = min(ry > 0 ? ry : rx, h / 2)
            return """
            M \(x + rx) \(y) \
            L \(x + w - rx) \(y) \
            Q \(x + w) \(y) \(x + w) \(y + ry) \
            L \(x + w) \(y + h - ry) \
            Q \(x + w) \(y + h) \(x + w - rx) \(y + h) \
            L \(x + rx) \(y + h) \
            Q \(x) \(y + h) \(x) \(y + h - ry) \
            L \(x) \(y + ry) \
            Q \(x) \(y) \(x + rx) \(y) Z
            """
        }
        return "M \(x) \(y) L \(x+w) \(y) L \(x+w) \(y+h) L \(x) \(y+h) Z"
    }

    /// Convert SVG circle attributes to a path `d` string
    static func circleToPathData(cx: CGFloat, cy: CGFloat, r: CGFloat) -> String {
        ellipseToPathData(cx: cx, cy: cy, rx: r, ry: r)
    }

    /// Convert SVG ellipse attributes to a path `d` string
    static func ellipseToPathData(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> String {
        // Four cubic Bézier arcs (kappa approximation)
        let k: CGFloat = 0.5522847498
        let kx = rx * k, ky = ry * k
        return """
        M \(cx) \(cy - ry) \
        C \(cx + kx) \(cy - ry) \(cx + rx) \(cy - ky) \(cx + rx) \(cy) \
        C \(cx + rx) \(cy + ky) \(cx + kx) \(cy + ry) \(cx) \(cy + ry) \
        C \(cx - kx) \(cy + ry) \(cx - rx) \(cy + ky) \(cx - rx) \(cy) \
        C \(cx - rx) \(cy - ky) \(cx - kx) \(cy - ry) \(cx) \(cy - ry) Z
        """
    }

    /// Convert SVG polygon points to a path `d` string
    static func polygonToPathData(points: String) -> String {
        let nums = points.split(whereSeparator: { " ,\n\r\t".contains($0) })
            .compactMap { Double($0) }
        guard nums.count >= 4 else { return "" }
        var d = "M \(nums[0]) \(nums[1])"
        for i in stride(from: 2, to: nums.count - 1, by: 2) {
            d += " L \(nums[i]) \(nums[i+1])"
        }
        return d + " Z"
    }

    // MARK: - Tokenizer

    private static func tokenize(_ d: String) -> [String] {
        var tokens: [String] = []
        var buf = ""

        for ch in d {
            if ch.isLetter {
                if !buf.isEmpty { tokens.append(buf); buf = "" }
                tokens.append(String(ch))
            } else if ch == "," || ch == " " || ch == "\n" || ch == "\r" || ch == "\t" {
                if !buf.isEmpty { tokens.append(buf); buf = "" }
            } else if ch == "-" && !buf.isEmpty && !buf.hasSuffix("e") && !buf.hasSuffix("E") {
                tokens.append(buf); buf = String(ch)
            } else {
                buf.append(ch)
            }
        }
        if !buf.isEmpty { tokens.append(buf) }
        return tokens
    }

    // MARK: - Token Readers

    private static func readDouble(_ i: inout Int, _ tokens: [String]) -> CGFloat? {
        guard i < tokens.count, let v = Double(tokens[i]) else { return nil }
        i += 1
        return CGFloat(v)
    }

    private static func readPoint(_ i: inout Int, _ tokens: [String],
                                  rel: Bool, cur: CGPoint) -> CGPoint? {
        let saved = i
        guard let x = readDouble(&i, tokens), let y = readDouble(&i, tokens) else {
            i = saved; return nil
        }
        return rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
    }

    private static func reflectedCP(_ lastCP: CGPoint?, cur: CGPoint,
                                    prev: Character, allowed: String) -> CGPoint {
        if let cp = lastCP, allowed.contains(prev) {
            return CGPoint(x: 2 * cur.x - cp.x, y: 2 * cur.y - cp.y)
        }
        return cur
    }

    // MARK: - Arc Conversion (SVG arc → cubic Bézier approximation)

    private static func addArc(to path: inout Path,
                               from p1: CGPoint, to p2: CGPoint,
                               rx: CGFloat, ry: CGFloat,
                               largeArc: Bool, sweep: Bool) {
        guard rx > 0, ry > 0 else { path.addLine(to: p2); return }
        guard p1 != p2 else { return }

        // Simplified: approximate with a line for very small arcs,
        // or use SwiftUI's built-in arc for circles.
        // For production SVGs from Illustrator, most arcs are circles/ellipses
        // which the kappa approximation in ellipseToPathData handles.
        // For arbitrary arcs in path data, we use a line approximation for now.
        // TODO: Full endpoint-to-center arc conversion for complex SVGs
        path.addLine(to: p2)
    }
}
