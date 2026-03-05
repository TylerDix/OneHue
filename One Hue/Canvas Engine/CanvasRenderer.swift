import SwiftUI

struct CanvasRenderer: View {
    let artwork: DailyArtwork
    let filled: Set<Int>
    let pulse: FillPulse?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )

                ForEach(artwork.regions) { region in
                    let scaled = HitTest.scaledPath(region.path, to: size)
                    let isFilled = filled.contains(region.id)

                    ZStack {
                        // Watercolor-ish halo (blurred ink bloom)
                        if isFilled {
                            scaled
                                .fill(artwork.palette[region.colorIndex].opacity(0.55))
                                .blur(radius: 10)
                                .scaleEffect(bloomScale(for: region.id) * 1.01)
                                .opacity(isPulsing(region.id) ? 1.0 : 0.9)
                        }

                        // Main fill
                        scaled
                            .fill(isFilled ? artwork.palette[region.colorIndex] : Color.white.opacity(0.06))
                            .overlay(scaled.stroke(.white.opacity(0.12), lineWidth: 1))
                            .scaleEffect(bloomScale(for: region.id))
                    }
                    .animation(.easeOut(duration: FillAnimation.duration), value: pulse)
                }
            }
            .padding(10)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func isPulsing(_ regionID: Int) -> Bool {
        pulse?.regionID == regionID
    }

    private func bloomScale(for regionID: Int) -> CGFloat {
        isPulsing(regionID) ? FillAnimation.bloomScale : 1.0
    }
}
