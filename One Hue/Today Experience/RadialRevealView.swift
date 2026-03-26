import SwiftUI
import Combine

/// Completion reveal: a warm glow ring expands from the user's last tap
/// point, sweeping outward across the artwork before fading away.
/// Uses CADisplayLink for smooth 60fps — same pattern as the blob fills.
struct RadialRevealView: View {

    /// Normalized origin (0…1) relative to the view's bounds.
    /// Falls back to center if nil.
    let origin: CGPoint?
    @Binding var isActive: Bool

    @StateObject private var engine = WaveRevealEngine()

    var body: some View {
        Canvas { context, size in
            guard engine.ringOpacity > 0 else { return }

            let o = origin ?? CGPoint(x: 0.5, y: 0.5)
            let cx = o.x * size.width
            let cy = o.y * size.height
            let center = CGPoint(x: cx, y: cy)

            // Max radius = distance from origin to the farthest corner
            let maxR = [
                CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
                CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
            ].map { hypot($0.x - cx, $0.y - cy) }.max() ?? size.width

            let radius = engine.normalizedRadius * maxR
            let ringWidth = min(size.height * 0.08, 120.0)

            let innerR = max(radius - ringWidth, 0)
            let outerR = radius + ringWidth

            // Warm white glow color
            let glowColor = Color(hue: 0.08, saturation: 0.12, brightness: 1.0)
            let peak = engine.ringOpacity

            // Build gradient stops for the annular ring.
            // The ring fades: transparent → glow → transparent across [innerR, outerR].
            // We express stops as fractions of outerR (the radial gradient's end radius).
            let innerFrac = outerR > 0 ? innerR / outerR : 0
            let centerFrac = outerR > 0 ? radius / outerR : 0.5

            // Feather zone just inside the inner edge
            let featherInner = max(innerFrac - 0.04, 0)

            let gradient = Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: featherInner),
                .init(color: glowColor.opacity(peak * 0.10), location: innerFrac),
                .init(color: glowColor.opacity(peak * 0.35), location: centerFrac),
                .init(color: glowColor.opacity(peak * 0.10), location: 1.0),
            ])

            let disc = Path(ellipseIn: CGRect(
                x: cx - outerR, y: cy - outerR,
                width: outerR * 2, height: outerR * 2
            ))

            context.fill(disc, with: .radialGradient(
                gradient,
                center: center,
                startRadius: 0,
                endRadius: outerR
            ))
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active { engine.start() }
        }
    }
}

// MARK: - Engine

private class WaveRevealEngine: ObservableObject {

    /// 0…1 — how far the ring has expanded
    @Published var normalizedRadius: CGFloat = 0
    /// 0…1 — ring glow brightness
    @Published var ringOpacity: CGFloat = 0

    private var displayLink: PlatformDisplayLink?
    private var startTime: Date = .now

    // Timing
    private let expandDuration: TimeInterval = 2.0
    private let afterglowDuration: TimeInterval = 0.3
    private var totalDuration: TimeInterval { expandDuration + afterglowDuration }
    private let peakOpacity: CGFloat = 1.0  // gradient stops scale this down

    func start() {
        normalizedRadius = 0
        ringOpacity = 0
        startTime = .now
        startLoop()
    }

    private func startLoop() {
        guard displayLink == nil else { return }
        let link = PlatformDisplayLink { [weak self] in self?.tick() }
        link.start()
        displayLink = link
    }

    private func stopLoop() {
        displayLink?.stop()
        displayLink = nil
        normalizedRadius = 0
        ringOpacity = 0
    }

    private func tick() {
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > totalDuration {
            stopLoop()
            return
        }

        if elapsed < expandDuration {
            // Ring expands with ease-out cubic
            let t = elapsed / expandDuration
            let eased = 1.0 - pow(1.0 - t, 3)
            normalizedRadius = eased

            // Quick fade-in over first 0.15s, then hold
            ringOpacity = min(CGFloat(t / 0.075), 1.0) * peakOpacity
        } else {
            // Afterglow: ring stays at full size, opacity fades out
            normalizedRadius = 1.0
            let fadeT = (elapsed - expandDuration) / afterglowDuration
            ringOpacity = peakOpacity * CGFloat(1.0 - fadeT)
        }
    }

    deinit {
        displayLink?.stop()
    }
}
