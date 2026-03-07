import CoreGraphics

/// Parses an SVG path `d` attribute string into a CGPath.
/// Supports: M/m, L/l, H/h, V/v, C/c, S/s, Q/q, Z/z
enum SVGPathParser {

    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        let tokens = tokenize(d)
        var i = 0
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControl: CGPoint?   // last cubic control point for S/s
        var lastCommand: Character = " "

        while i < tokens.count {
            let token = tokens[i]

            if let cmd = token.asCommand {
                i += 1
                lastCommand = cmd
                processCommand(cmd, tokens: tokens, index: &i, path: path,
                               current: &currentPoint, subpathStart: &subpathStart,
                               lastControl: &lastControl, lastCmd: &lastCommand)
            } else {
                // Implicit repeat of the last command
                processCommand(lastCommand, tokens: tokens, index: &i, path: path,
                               current: &currentPoint, subpathStart: &subpathStart,
                               lastControl: &lastControl, lastCmd: &lastCommand)
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
        lastControl: inout CGPoint?,
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
            lastControl = nil
            // Subsequent coordinate pairs after M are implicit L
            lastCmd = rel ? "l" : "L"

        case "l":
            guard let pt = readPoint(tokens, at: &i) else { return }
            let dest = rel ? current + pt : pt
            path.addLine(to: dest)
            current = dest
            lastControl = nil

        case "h":
            guard let x = readNumber(tokens, at: &i) else { return }
            let dest = CGPoint(x: rel ? current.x + x : x, y: current.y)
            path.addLine(to: dest)
            current = dest
            lastControl = nil

        case "v":
            guard let y = readNumber(tokens, at: &i) else { return }
            let dest = CGPoint(x: current.x, y: rel ? current.y + y : y)
            path.addLine(to: dest)
            current = dest
            lastControl = nil

        case "c":
            guard let cp1 = readPoint(tokens, at: &i),
                  let cp2 = readPoint(tokens, at: &i),
                  let end = readPoint(tokens, at: &i) else { return }
            let c1 = rel ? current + cp1 : cp1
            let c2 = rel ? current + cp2 : cp2
            let dest = rel ? current + end : end
            path.addCurve(to: dest, control1: c1, control2: c2)
            lastControl = c2
            current = dest

        case "s":
            guard let cp2 = readPoint(tokens, at: &i),
                  let end = readPoint(tokens, at: &i) else { return }
            // Reflect the last cubic control point
            let c1: CGPoint
            if let lc = lastControl {
                c1 = CGPoint(x: 2 * current.x - lc.x, y: 2 * current.y - lc.y)
            } else {
                c1 = current
            }
            let c2 = rel ? current + cp2 : cp2
            let dest = rel ? current + end : end
            path.addCurve(to: dest, control1: c1, control2: c2)
            lastControl = c2
            current = dest

        case "q":
            guard let cp = readPoint(tokens, at: &i),
                  let end = readPoint(tokens, at: &i) else { return }
            let c = rel ? current + cp : cp
            let dest = rel ? current + end : end
            path.addQuadCurve(to: dest, control: c)
            lastControl = nil  // Q doesn't set cubic control
            current = dest

        case "z":
            path.closeSubpath()
            current = subpathStart
            lastControl = nil

        default:
            break
        }
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
