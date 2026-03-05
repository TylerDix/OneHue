import SwiftUI

enum HitTest {

    /// Returns the first region whose scaled path contains the point (with optional tolerance).
    /// - Parameters:
    ///   - point: point in view coordinates
    ///   - size: view size
    ///   - regions: normalized paths (0...1)
    ///   - tolerance: extra hit area in points (good for finger input)
    static func regionID(
        at point: CGPoint,
        in size: CGSize,
        regions: [Region],
        tolerance: CGFloat = 8
    ) -> Int? {
        for r in regions {
            let scaled = scaledPath(r.path, to: size)

            // 1) True inside hit
            if scaled.contains(point, eoFill: true) {
                return r.id
            }

            // 2) Touch-forgiving hit (near border / thin regions)
            // Create a stroked outline and treat it like a "hit band"
            if tolerance > 0 {
                let hitBand = scaled
                    .strokedPath(.init(lineWidth: tolerance * 2, lineCap: .round, lineJoin: .round))
                if hitBand.contains(point, eoFill: true) {
                    return r.id
                }
            }
        }
        return nil
    }

    static func scaledPath(_ path: Path, to size: CGSize) -> Path {
        var t = CGAffineTransform(scaleX: size.width, y: size.height)
        return path.applying(t)
    }
}
