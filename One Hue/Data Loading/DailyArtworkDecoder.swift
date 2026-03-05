import SwiftUI

enum DailyArtworkDecoder {

    struct RGB: Decodable {
        let r: Double
        let g: Double
        let b: Double
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
        let shape: ShapeSpec
    }

    struct ArtworkDTO: Decodable {
        let id: String
        let title: String
        let completionMessage: String
        let palette: [RGB]
        let regions: [RegionDTO]
    }

    static func loadBundledJSON(named name: String) throws -> DailyArtwork {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "OneHue", code: 404, userInfo: [NSLocalizedDescriptionKey: "Missing \(name).json in app bundle"])
        }
        let data = try Data(contentsOf: url)
        let dto = try JSONDecoder().decode(ArtworkDTO.self, from: data)

        let palette = dto.palette.map { Color(red: $0.r, green: $0.g, blue: $0.b) }
        let regions = dto.regions.map { r in
            Region(id: r.id, number: r.number, colorIndex: r.colorIndex, path: path(from: r.shape))
        }

        return DailyArtwork(
            id: dto.id,
            title: dto.title,
            completionMessage: dto.completionMessage,
            palette: palette,
            regions: regions
        )
    }

    private static func path(from s: ShapeSpec) -> Path {
        switch s.type.lowercased() {
        case "ellipse":
            return Path(ellipseIn: CGRect(x: s.x, y: s.y, width: s.w, height: s.h))

        case "roundrect":
            return Path { p in
                p.addRoundedRect(
                    in: CGRect(x: s.x, y: s.y, width: s.w, height: s.h),
                    cornerSize: CGSize(width: s.rx ?? 0.0, height: s.ry ?? 0.0)
                )
            }

        case "rect":
            return Path(CGRect(x: s.x, y: s.y, width: s.w, height: s.h))

        default:
            // fallback to rect so app still runs
            return Path(CGRect(x: s.x, y: s.y, width: s.w, height: s.h))
        }
    }
}
