import SwiftUI

/// Decodes JSON artwork manifests into `DailyArtwork` models.
///
/// Supports two JSON formats:
/// 1. **Path-based** (production) — regions have a `pathData` field with SVG `d` strings
/// 2. **Shape-based** (legacy/simple) — regions have a `shape` object with type/x/y/w/h
///
/// The decoder auto-detects which format each region uses.
enum DailyArtworkDecoder {

    // MARK: - JSON DTOs

    struct PaletteColorDTO: Decodable {
        // Supports two formats:
        // { "r": 1.0, "g": 0.2, "b": 0.2 }           — RGB floats
        // { "hex": "#FF3333", "name": "Warm Red" }     — hex string
        let r: Double?
        let g: Double?
        let b: Double?
        let hex: String?
        let name: String?

        var color: Color {
            if let hex = hex {
                return Color(hex: hex)
            }
            return Color(red: r ?? 0, green: g ?? 0, blue: b ?? 0)
        }
    }

    struct ShapeSpec: Decodable {
        let type: String
        let x: Double
        let y: Double
        let w: Double
        let h: Double
        let rx: Double?
        let ry: Double?
    }

    struct RegionDTO: Decodable {
        let id: Int
        let number: Int
        let colorIndex: Int
        // Path-based (production)
        let pathData: String?
        // Shape-based (legacy)
        let shape: ShapeSpec?
        // Optional label position
        let labelX: Double?
        let labelY: Double?

        enum CodingKeys: String, CodingKey {
            case id, number, colorIndex
            case pathData = "path_data"
            case shape
            case labelX = "label_x"
            case labelY = "label_y"
        }
    }

    struct ArtworkDTO: Decodable {
        let id: String
        let title: String
        let subject: String?
        let completionMessage: String
        let palette: [PaletteColorDTO]
        let regions: [RegionDTO]
        // Optional viewBox (default 1×1 for normalized coordinates)
        let viewBoxWidth: Double?
        let viewBoxHeight: Double?

        enum CodingKeys: String, CodingKey {
            case id, title, subject, completionMessage, palette, regions
            case viewBoxWidth = "view_box_width"
            case viewBoxHeight = "view_box_height"
        }
    }

    // MARK: - Public API

    /// Load a JSON artwork manifest from the app bundle.
    static func loadBundledJSON(named name: String) throws -> DailyArtwork {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw OneHueError.fileNotFound("\(name).json")
        }
        let data = try Data(contentsOf: url)
        return try decode(data: data)
    }

    /// Decode JSON data into a DailyArtwork.
    static func decode(data: Data) throws -> DailyArtwork {
        let dto = try JSONDecoder().decode(ArtworkDTO.self, from: data)

        let vw = CGFloat(dto.viewBoxWidth ?? 1.0)
        let vh = CGFloat(dto.viewBoxHeight ?? 1.0)

        let palette = dto.palette.map { $0.color }

        let regions: [Region] = dto.regions.map { r in
            let path: Path
            let labelCenter: CGPoint?

            if let pathData = r.pathData, !pathData.isEmpty {
                // Production format: SVG path data, already in normalized coordinates
                path = SVGPathParser.path(from: pathData)
            } else if let s = r.shape {
                // Legacy format: simple shape spec
                path = shapePath(from: s)
            } else {
                // Fallback: empty path
                path = Path()
            }

            if let lx = r.labelX, let ly = r.labelY {
                labelCenter = CGPoint(x: lx, y: ly)
            } else {
                labelCenter = nil
            }

            return Region(
                id: r.id,
                number: r.number,
                colorIndex: r.colorIndex,
                path: path,
                labelCenter: labelCenter
            )
        }

        return DailyArtwork(
            id: dto.id,
            title: dto.title,
            subject: dto.subject ?? "",
            completionMessage: dto.completionMessage,
            palette: palette,
            regions: regions,
            viewBoxWidth: vw,
            viewBoxHeight: vh
        )
    }

    // MARK: - Legacy Shape Support

    private static func shapePath(from s: ShapeSpec) -> Path {
        switch s.type.lowercased() {
        case "ellipse":
            return Path(ellipseIn: CGRect(x: s.x, y: s.y, width: s.w, height: s.h))

        case "roundrect":
            return Path { p in
                p.addRoundedRect(
                    in: CGRect(x: s.x, y: s.y, width: s.w, height: s.h),
                    cornerSize: CGSize(width: s.rx ?? 0, height: s.ry ?? 0)
                )
            }

        case "circle":
            let r = min(s.w, s.h) / 2
            let d = SVGPathParser.circleToPathData(cx: s.x + r, cy: s.y + r, r: r)
            return SVGPathParser.path(from: d)

        default: // "rect" and fallback
            return Path(CGRect(x: s.x, y: s.y, width: s.w, height: s.h))
        }
    }
}
