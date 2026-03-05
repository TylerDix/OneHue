import SwiftUI

struct CanvasRenderer: View {
    let artwork: DailyArtwork
    let filled: Set<Int>
    let pulse: FillPulse?

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
                    let scaled = HitTest.scaledPath(region.path, to: size)
                    let isFilled = filled.contains(region.id)
                    let color = artwork.palette[safe: region.colorIndex] ?? .gray

                    ZStack {
                        // Region fill — simple color fade, no bloom, no scale
                        scaled
                            .fill(isFilled ? color : Color.white.opacity(0.06))
                            .overlay(
                                scaled.stroke(
                                    isFilled ? color.opacity(0.3) : .white.opacity(0.15),
                                    lineWidth: isFilled ? 0.5 : 1
                                )
                            )

                        // Number label (fades away on fill)
                        if !isFilled {
                            let labelPoint = regionLabelPoint(region, scaledPath: scaled, viewSize: size)
                            Text("\(region.number)")
                                .font(.system(
                                    size: numberFontSize(for: scaled, base: min(size.width, size.height)),
                                    weight: .semibold,
                                    design: .rounded
                                ))
                                .foregroundStyle(.white.opacity(0.55))
                                .position(labelPoint)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: FillAnimation.duration), value: isFilled)
                }
            }
            .padding(10)
        }
        .aspectRatio(artwork.aspectRatio, contentMode: .fit)
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
