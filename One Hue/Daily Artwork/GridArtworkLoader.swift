import SwiftUI

// MARK: - Color hex extension
// (Previously lived in SVGDocumentParser.swift)
extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double(rgb         & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

/// Loads grid-based artwork manifests from the app bundle.
///
/// Expected bundle files per day (e.g. 2026-03-05):
///   daily_2026-03-05.json   — grid manifest from image_to_grid_v2.py
///   daily_2026-03-05.png    — original high-quality source image
///
/// JSON format:
/// {
///   "id": "2026-03-05",
///   "title": "Peace",
///   "subject": "peace symbol",
///   "completionMessage": "...",
///   "cols": 80, "rows": 44,
///   "palette": ["#E8734A", ...],
///   "bgColorIndex": 7,
///   "outlineColorIndex": 8,      // optional
///   "grid": [0, 3, 3, 5, ...]
/// }
enum GridArtworkLoader {

    // MARK: - DTO

    private struct ManifestDTO: Decodable {
        let id: String
        let title: String
        let subject: String?
        let completionMessage: String
        let cols: Int
        let rows: Int
        let palette: [String]       // hex strings e.g. "#E8734A"
        let grid: [Int]
        let bgColorIndex: Int?
        let outlineColorIndex: Int?
    }

    // MARK: - Public

    /// Load artwork for a given day ID from the app bundle.
    /// Returns nil if the JSON manifest is not found.
    static func load(dayID: String) -> DailyArtwork? {
        let filename = "daily_\(dayID)"

        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dto = try? JSONDecoder().decode(ManifestDTO.self, from: data)
        else { return nil }

        let palette = dto.palette.map { Color(hex: $0) }

        // Load the source image — tries asset catalog first, then bundle path
        let sourceImage = UIImage(named: filename)
            ?? {
                if let url = Bundle.main.url(forResource: filename, withExtension: "png") {
                    return UIImage(contentsOfFile: url.path)
                }
                return nil
            }()

        return DailyArtwork(
            id: dto.id,
            title: dto.title,
            subject: dto.subject ?? "",
            completionMessage: dto.completionMessage,
            palette: palette,
            cols: dto.cols,
            rows: dto.rows,
            grid: dto.grid,
            bgColorIndex: dto.bgColorIndex,
            outlineColorIndex: dto.outlineColorIndex,
            sourceImage: sourceImage
        )
    }

    // MARK: - Mock Fallback

    /// Simple geometric peace sign for use when no bundle asset exists.
    static func makeMock(dayID: String) -> DailyArtwork {
        let palette: [Color] = [
            Color(hex: "#E8734A"),   // 0 orange
            Color(hex: "#D4A437"),   // 1 mustard
            Color(hex: "#7A9E6F"),   // 2 sage
            Color(hex: "#3D7A8A"),   // 3 teal
            Color(hex: "#C4826A"),   // 4 terracotta
            Color(hex: "#8B6E5A"),   // 5 brown
            Color(hex: "#F5F0E8"),   // 6 background (non-interactive)
        ]

        // 10×10 mini peace sign grid for testing
        let cols = 10, rows = 10
        let bg = 6
        //  0=orange 1=mustard 2=sage 3=teal bg=6
        let g: [[Int]] = [
            [bg, bg, bg, 2,  2,  2,  2, bg, bg, bg],
            [bg, bg, 2,  2,  0,  0,  2,  2, bg, bg],
            [bg, 2,  2,  0,  3,  3,  0,  2,  2, bg],
            [2,  2,  0,  3,  bg, bg, 3,  0,  2,  2],
            [2,  0,  3,  bg, bg, bg, bg, 3,  0,  2],
            [2,  0,  3,  1,  bg, bg, 1,  3,  0,  2],
            [2,  2,  0,  3,  1,  1,  3,  0,  2,  2],
            [bg, 2,  2,  0,  3,  3,  0,  2,  2, bg],
            [bg, bg, 2,  2,  0,  0,  2,  2, bg, bg],
            [bg, bg, bg, 2,  2,  2,  2, bg, bg, bg],
        ]

        return DailyArtwork(
            id: dayID,
            title: "Peace",
            subject: "peace symbol",
            completionMessage: "Today, [count] people traced the oldest wish in the world back into color. It still means what it always meant.",
            palette: palette,
            cols: cols,
            rows: rows,
            grid: g.flatMap { $0 },
            bgColorIndex: bg,
            outlineColorIndex: nil,
            sourceImage: nil
        )
    }
}
