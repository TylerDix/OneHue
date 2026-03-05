import SwiftUI

struct CanvasRenderer: View {
    let artwork: DailyArtwork
    let filled: Set<Int>
    let pulse: FillPulse?
    var numberOpacity: CGFloat = 0.55

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )

                // Regions
                ForEach(artwork.regions) { region in
                    regionView(region: region, size: size)
                }
            }
            .padding(10)
        }
        .aspectRatio(artwork.aspectRatio, contentMode: .fit)
    }

    // MARK: - Region View

    @ViewBuilder
    private func regionView(region: Region, size: CGSize) -> some View {
        let scaled = HitTest.scaledPath(region.path, to: size)
        let isFilled = filled.contains(region.id)
        let color = artwork.palette[safe: region.colorIndex] ?? .gray
        let labelPoint = regionLabelPoint(region, scaledPath: scaled, viewSize: size)

        ZStack {
            // Region fill:
            // - Filled: full color
            // - Unfilled: faint tint of the target color (so overview shows the image shape)
            scaled
                .fill(isFilled ? color : color.opacity(0.08))
                .overlay(
                    scaled.stroke(
                        isFilled ? color.opacity(0.3) : .white.opacity(0.2),
                        lineWidth: isFilled ? 0.5 : 0.75
                    )
                )

            // Number label — opacity controlled by zoom level
            if !isFilled && numberOpacity > 0.01 {
                Text("\(region.number)")
                    .font(.system(
                        size: numberFontSize(for: scaled, base: min(size.width, size.height)),
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundStyle(.white.opacity(numberOpacity))
                    .position(labelPoint)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: FillAnimation.duration), value: isFilled)
    }

    // MARK: - Helpers

    private func regionLabelPoint(_ region: Region, scaledPath: Path, viewSize: CGSize) -> CGPoint {
        if let lc = region.labelCenter {
            return CGPoint(x: lc.x * viewSize.width, y: lc.y * viewSize.height)
        }
        let rect = scaledPath.boundingRect
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private func numberFontSize(for path: Path, base: CGFloat) -> CGFloat {
        let rect = path.boundingRect
        let regionSize = min(rect.width, rect.height)
        return max(8, min(18, regionSize * 0.4))
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Previews

#Preview("Canvas — Mock") {
    let store = DailyArtworkStore()

    CanvasRenderer(
        artwork: store.artwork,
        filled: [],
        pulse: nil,
        numberOpacity: 0.55
    )
    .frame(width: 400, height: 400)
    .background(.black)
    .preferredColorScheme(.dark)
}

#Preview("Canvas — Numbers hidden") {
    let store = DailyArtworkStore()

    CanvasRenderer(
        artwork: store.artwork,
        filled: [],
        pulse: nil,
        numberOpacity: 0
    )
    .frame(width: 400, height: 400)
    .background(.black)
    .preferredColorScheme(.dark)
}
