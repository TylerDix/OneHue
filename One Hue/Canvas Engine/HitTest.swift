import SwiftUI

enum HitTest {

    /// Returns the first region whose scaled path contains the given point.
    /// - Parameters:
    ///   - point: point in view coordinates
    ///   - size: view size
    ///   - regions: normalized paths (0...1)
    static func regionID(at point: CGPoint, in size: CGSize, regions: [Region]) -> Int? {
        for r in regions {
            let scaled = scaledPath(r.path, to: size)
            if scaled.contains(point, eoFill: true) {
                return r.id
            }
        }
        return nil
    }

    static func scaledPath(_ path: Path, to size: CGSize) -> Path {
        var t = CGAffineTransform(scaleX: size.width, y: size.height)
        return path.applying(t)
    }
}
