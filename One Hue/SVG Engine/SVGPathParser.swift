import CoreGraphics
import Foundation

/// Parses an SVG path `d` attribute string into a CGPath.
/// Supports: M/m, L/l, H/h, V/v, C/c, S/s, Q/q, T/t, A/a, Z/z
enum SVGPathParser {

    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        let tokens = tokenize(d)
        var i = 0
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCubicControl: CGPoint?    // last cubic control point for S/s
        var lastQuadControl: CGPoint?     // last quadratic control point for T/t
        var lastCommand: Character = " "

        while i < tokens.count {
            let token = tokens[i]

            if let cmd = token.asCommand {
                i += 1
                lastCommand = cmd
                processCommand(cmd, tokens: tokens, index: &i, path: path,
                               current: &currentPoint, subpathStart: &subpathStart,
                               lastCubicControl: &lastCubicControl,
                               lastQuadControl: &lastQuadControl,
                               lastCmd: &lastCommand)
            } else {
                // Implicit repeat of the last command
                processCommand(lastCommand, tokens: tokens, index: &i, path: path,
                               current: &currentPoint, subpathStart: &subpathStart,
                               lastCubicControl: &lastCubicControl,
                               lastQuadControl: &lastQuadControl,
                               lastCmd: &lastCommand)
            }
        }

        return path
    }

    // MARK: - Command Processing

    private static func processCommand(
        _ cmd: Character,
        tokens: [Token],
        index i: inout Int,
        path: CGMutablePath,
        current: inout CGPoint,
        subpathStart: inout CGPoint,
        lastCubicControl: inout CGPoint?,
        lastQuadControl: inout CGPoint?,
        lastCmd: inout Character
    ) {
        let rel = cmd.isLowercase

        switch cmd.lowercased().first! {
        case "m":
            guard let pt = readPoint(tokens, at: &i) else { return }
            let dest = rel ? current + pt : pt
            path.move(to: dest)
            current = dest
            subpathStart = dest
            lastCubicControl = nil
            lastQuadControl = nil
            // Subsequent coordinate pairs after M are implicit L
            lastCmd = rel ? "l" : "L"

        case "l":
            guard let pt = readPoint(tokens, at: &i) else { return }
            let dest = rel ? current + pt : pt
            path.addLine(to: dest)
            current = dest
            lastCubicControl = nil
            lastQuadControl = nil

        case "h":
            guard let x = readNumber(tokens, at: &i) else { return }
            let dest = CGPoint(x: rel ? current.x + x : x, y: current.y)
            path.addLine(to: dest)
            current = dest
            lastCubicControl = nil
            lastQuadControl = nil

        case "v":
            guard let y = readNumber(tokens, at: &i) else { return }
            let dest = CGPoint(x: current.x, y: rel ? current.y + y : y)
            path.addLine(to: dest)
            current = dest
            lastCubicControl = nil
            lastQuadControl = nil

        case "c":
            guard let cp1 = readPoint(tokens, at: &i),
                  let cp2 = readPoint(tokens, at: &i),
                  let end = readPoint(tokens, at: &i) else { return }
            let c1 = rel ? current + cp1 : cp1
            let c2 = rel ? current + cp2 : cp2
            let dest = rel ? current + end : end
            path.addCurve(to: dest, control1: c1, control2: c2)
            lastCubicControl = c2
            lastQuadControl = nil
            current = dest

        case "s":
            guard let cp2 = readPoint(tokens, at: &i),
                  let end = readPoint(tokens, at: &i) else { return }
            // Reflect the last cubic control point
            let c1: CGPoint
            if let lc = lastCubicControl {
                c1 = CGPoint(x: 2 * current.x - lc.x, y: 2 * current.y - lc.y)
            } else {
                c1 = current
            }
            let c2 = rel ? current + cp2 : cp2
            let dest = rel ? current + end : end
            path.addCurve(to: dest, control1: c1, control2: c2)
            lastCubicControl = c2
            lastQuadControl = nil
            current = dest

        case "q":
            guard let cp = readPoint(tokens, at: &i),
                  let end = readPoint(tokens, at: &i) else { return }
            let c = rel ? current + cp : cp
            let dest = rel ? current + end : end
            path.addQuadCurve(to: dest, control: c)
            lastQuadControl = c
            lastCubicControl = nil
            current = dest

        case "t":
            guard let end = readPoint(tokens, at: &i) else { return }
            let dest = rel ? current + end : end
            // Reflect the last quadratic control point across current
            let cp: CGPoint
            if let lqc = lastQuadControl {
                cp = CGPoint(x: 2 * current.x - lqc.x, y: 2 * current.y - lqc.y)
            } else {
                cp = current
            }
            path.addQuadCurve(to: dest, control: cp)
            lastQuadControl = cp
            lastCubicControl = nil
            current = dest

        case "a":
            guard let rxRaw = readNumber(tokens, at: &i),
                  let ryRaw = readNumber(tokens, at: &i),
                  let xRotDeg = readNumber(tokens, at: &i),
                  let largeArcNum = readNumber(tokens, at: &i),
                  let sweepNum = readNumber(tokens, at: &i),
                  let endPt = readPoint(tokens, at: &i) else { return }
            let dest = rel ? current + endPt : endPt
            arcToBeziers(path: path, from: current, to: dest,
                         rx: abs(rxRaw), ry: abs(ryRaw),
                         xRotation: xRotDeg * .pi / 180,
                         largeArc: largeArcNum != 0,
                         sweep: sweepNum != 0)
            current = dest
            lastCubicControl = nil
            lastQuadControl = nil

        case "z":
            path.closeSubpath()
            current = subpathStart
            lastCubicControl = nil
            lastQuadControl = nil

        default:
            break
        }
    }

    // MARK: - Arc Conversion (SVG spec F.6.5 – F.6.6)

    /// Converts an SVG endpoint-parameterized arc into cubic bezier segments
    /// and appends them to the path.
    private static func arcToBeziers(
        path: CGMutablePath,
        from p1: CGPoint, to p2: CGPoint,
        rx rxIn: CGFloat, ry ryIn: CGFloat,
        xRotation phi: CGFloat,
        largeArc fA: Bool, sweep fS: Bool
    ) {
        // Degenerate: zero-length arc
        guard p1.x != p2.x || p1.y != p2.y else { return }

        // Degenerate: zero radii → straight line
        guard rxIn > 0 && ryIn > 0 else {
            path.addLine(to: p2)
            return
        }

        var rx = rxIn
        var ry = ryIn
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        // Step 1: Compute (x1', y1') in rotated midpoint frame
        let dx = (p1.x - p2.x) / 2
        let dy = (p1.y - p2.y) / 2
        let x1p =  cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // Step 2: Scale up radii if too small
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let sqrtLambda = sqrt(lambda)
            rx *= sqrtLambda
            ry *= sqrtLambda
        }

        // Step 3: Compute center point (cx', cy') in rotated frame
        let rx2 = rx * rx, ry2 = ry * ry
        let x1p2 = x1p * x1p, y1p2 = y1p * y1p
        var num = rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2
        let den = rx2 * y1p2 + ry2 * x1p2
        if num < 0 { num = 0 }  // numerical safety
        var sq = sqrt(num / den)
        if fA == fS { sq = -sq }
        let cxp =  sq * (rx * y1p / ry)
        let cyp = -sq * (ry * x1p / rx)

        // Step 4: Compute center (cx, cy) in original space
        let cx = cosPhi * cxp - sinPhi * cyp + (p1.x + p2.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p1.y + p2.y) / 2

        // Step 5: Compute start angle and sweep angle
        let ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry

        let theta1 = vectorAngle(1, 0, ux, uy)
        var dTheta = vectorAngle(ux, uy, vx, vy)

        // Constrain sweep per flags
        if !fS && dTheta > 0 { dTheta -= 2 * .pi }
        if  fS && dTheta < 0 { dTheta += 2 * .pi }

        // Step 6: Split into bezier segments (each ≤ π/2)
        let segCount = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let segAngle = dTheta / CGFloat(segCount)

        for seg in 0..<segCount {
            let a1 = theta1 + CGFloat(seg) * segAngle
            let a2 = a1 + segAngle
            appendArcSegment(path: path, cx: cx, cy: cy, rx: rx, ry: ry,
                             phi: phi, a1: a1, a2: a2)
        }
    }

    /// Angle between vectors (ux, uy) and (vx, vy)
    private static func vectorAngle(_ ux: CGFloat, _ uy: CGFloat,
                                     _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
        let dot = ux * vx + uy * vy
        let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
        guard len > 0 else { return 0 }
        var angle = acos(max(-1, min(1, dot / len)))
        if ux * vy - uy * vx < 0 { angle = -angle }
        return angle
    }

    /// Approximate a single arc segment (≤ π/2) with a cubic bezier.
    private static func appendArcSegment(
        path: CGMutablePath,
        cx: CGFloat, cy: CGFloat,
        rx: CGFloat, ry: CGFloat,
        phi: CGFloat, a1: CGFloat, a2: CGFloat
    ) {
        let alpha = a2 - a1
        // Magic number for cubic bezier arc approximation
        let t = tan(alpha / 2)
        let sinAlpha = sin(alpha)
        guard abs(sinAlpha) > 1e-10 else { return }
        let f = (4.0 / 3.0) * t / (1 + cos(alpha))

        // Endpoints and control points on unit circle
        let cos1 = cos(a1), sin1 = sin(a1)
        let cos2 = cos(a2), sin2 = sin(a2)

        let cp1x = cos1 - f * sin1
        let cp1y = sin1 + f * cos1
        let cp2x = cos2 + f * sin2
        let cp2y = sin2 - f * cos2

        // Transform from unit circle → ellipse → original space
        let cosPhi = cos(phi), sinPhi = sin(phi)

        func transform(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
            let sx = px * rx
            let sy = py * ry
            return CGPoint(
                x: cosPhi * sx - sinPhi * sy + cx,
                y: sinPhi * sx + cosPhi * sy + cy
            )
        }

        let c1 = transform(cp1x, cp1y)
        let c2 = transform(cp2x, cp2y)
        let end = transform(cos2, sin2)

        path.addCurve(to: end, control1: c1, control2: c2)
    }

    // MARK: - Tokenizer

    private enum Token {
        case number(CGFloat)
        case command(Character)

        var asCommand: Character? {
            if case .command(let c) = self { return c }
            return nil
        }

        var asNumber: CGFloat? {
            if case .number(let n) = self { return n }
            return nil
        }
    }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(d)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            if ch.isWhitespace || ch == "," {
                i += 1
                continue
            }

            if isCommandChar(ch) {
                tokens.append(.command(ch))
                i += 1
                continue
            }

            // Parse number
            if let (num, end) = parseNumber(chars, from: i) {
                tokens.append(.number(CGFloat(num)))
                i = end
                continue
            }

            i += 1
        }

        return tokens
    }

    private static func isCommandChar(_ c: Character) -> Bool {
        "MmLlHhVvCcSsQqTtAaZz".contains(c)
    }

    private static func parseNumber(_ chars: [Character], from start: Int) -> (Double, Int)? {
        var i = start
        var str = ""

        // Optional sign
        if i < chars.count && (chars[i] == "-" || chars[i] == "+") {
            str.append(chars[i])
            i += 1
        }

        var hasDigit = false

        // Integer part
        while i < chars.count && chars[i].isNumber {
            str.append(chars[i])
            i += 1
            hasDigit = true
        }

        // Decimal part
        if i < chars.count && chars[i] == "." {
            str.append(".")
            i += 1
            while i < chars.count && chars[i].isNumber {
                str.append(chars[i])
                i += 1
                hasDigit = true
            }
        }

        // Exponent
        if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
            str.append(chars[i])
            i += 1
            if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
                str.append(chars[i])
                i += 1
            }
            while i < chars.count && chars[i].isNumber {
                str.append(chars[i])
                i += 1
            }
        }

        guard hasDigit, let value = Double(str) else { return nil }
        return (value, i)
    }

    // MARK: - Helpers

    private static func readNumber(_ tokens: [Token], at i: inout Int) -> CGFloat? {
        guard i < tokens.count, let n = tokens[i].asNumber else { return nil }
        i += 1
        return n
    }

    private static func readPoint(_ tokens: [Token], at i: inout Int) -> CGPoint? {
        guard let x = readNumber(tokens, at: &i),
              let y = readNumber(tokens, at: &i) else { return nil }
        return CGPoint(x: x, y: y)
    }
}

// MARK: - CGPoint arithmetic

private extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}
