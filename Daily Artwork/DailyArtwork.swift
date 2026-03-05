import SwiftUI

/// The three states a daily artwork moves through.
enum ArtworkPhase: Equatable {
    case pristine    // Full-quality image, no grid, "tap to begin"
    case painting    // Grid visible, cells fillable
    case complete    // Grid dissolves, original image returns
}

/// One day's color-by-number artwork — grid-based.
struct DailyArtwork: Identifiable {
    let id: String                  // e.g. "2026-03-05"
    let title: String               // e.g. "Peace"
    let subject: String
    let completionMessage: String   // includes [count] placeholder
    let palette: [Color]            // colorable palette entries only
    let cols: Int                   // grid columns
    let rows: Int                   // grid rows
    let grid: [Int]                 // flat row-major array of palette indices
    let bgColorIndex: Int?          // non-interactive background cells
    let outlineColorIndex: Int?     // non-interactive outline cells
    let sourceImage: UIImage?       // original high-quality PNG

    /// Aspect ratio of the grid (used for layout)
    var aspectRatio: CGFloat {
        guard rows > 0 else { return 4.0 / 3.0 }
        return CGFloat(cols) / CGFloat(rows)
    }

    /// Total number of cells the user must fill (excludes bg + outline)
    var fillableCellCount: Int {
        grid.filter { !isNonInteractive($0) }.count
    }

    /// Returns true if a palette index is non-interactive (bg or outline)
    func isNonInteractive(_ colorIndex: Int) -> Bool {
        colorIndex == bgColorIndex || colorIndex == outlineColorIndex
    }

    /// Returns the flat grid index for a given col/row
    func gridIndex(col: Int, row: Int) -> Int {
        row * cols + col
    }

    /// Returns the palette index at a given col/row
    func colorIndex(col: Int, row: Int) -> Int {
        guard col >= 0, col < cols, row >= 0, row < rows else { return bgColorIndex ?? 0 }
        return grid[gridIndex(col: col, row: row)]
    }
}
