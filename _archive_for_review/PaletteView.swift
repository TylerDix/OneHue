import SwiftUI

/// Bottom-anchored color palette for One Hue.
/// Each swatch shows its palette number and remaining cell count.
/// Completed colors get a quiet checkmark. Auto-scrolls to selection.
struct PaletteView: View {

    let palette: [Color]
    @Binding var selectedIndex: Int
    let filledCells: [GridCell: Int]
    let artwork: DailyArtwork
    let isComplete: Bool

    @State private var hasAppeared = false

    var body: some View {
        if !isComplete {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: swatchSpacing) {
                        ForEach(Array(palette.enumerated()), id: \.offset) { idx, color in
                            // Skip non-interactive colors (bg, outline)
                            if !artwork.isNonInteractive(idx) {
                                let remaining = remainingCount(for: idx)
                                let total = totalCount(for: idx)

                                swatchButton(
                                    index: idx,
                                    color: color,
                                    remaining: remaining,
                                    total: total
                                )
                                .id(idx)
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 10)
                                .animation(
                                    .easeOut(duration: 0.3).delay(Double(idx) * 0.025),
                                    value: hasAppeared
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .onChange(of: selectedIndex) { _, newIdx in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Swatch

    @ViewBuilder
    private func swatchButton(index: Int, color: Color, remaining: Int, total: Int) -> some View {
        let isSelected = index == selectedIndex
        let isDone = remaining == 0
        let size: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 46 : 38

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIndex = index
            }
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(isDone ? 0.1 : 0.2), lineWidth: 1)
                    )
                    .opacity(isDone ? 0.45 : 1.0)

                if isSelected {
                    Circle()
                        .strokeBorder(.white.opacity(0.9), lineWidth: 2.5)
                        .frame(width: size + 8, height: size + 8)
                }

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .transition(.opacity)
                } else {
                    VStack(spacing: -1) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)

                        if remaining < total {
                            Text("\(remaining)")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                        }
                    }
                }
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isSelected)
            .animation(.easeOut(duration: 0.25), value: isDone)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Counts

    /// How many cells with this colorIndex are still unfilled
    private func remainingCount(for colorIndex: Int) -> Int {
        totalCount(for: colorIndex) - filledCount(for: colorIndex)
    }

    /// Total cells in the grid with this colorIndex
    private func totalCount(for colorIndex: Int) -> Int {
        artwork.grid.filter { $0 == colorIndex }.count
    }

    /// How many cells with this colorIndex have been filled
    private func filledCount(for colorIndex: Int) -> Int {
        filledCells.values.filter { $0 == colorIndex }.count
    }

    private var swatchSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 12 : 10
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Palette — in progress") {
    let store = DailyArtworkStore()
    store.beginPainting()
    return PaletteView(
        palette: store.artwork.palette,
        selectedIndex: .constant(0),
        filledCells: store.filledCells,
        artwork: store.artwork,
        isComplete: false
    )
    .padding()
    .background(Color.black)
}
#endif
