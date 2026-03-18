import SwiftUI
import Combine

/// Completion reveal: a soft white circle expands from the user's last tap
/// point, briefly washing the artwork in light before fading away.
/// Uses CADisplayLink for smooth 60fps — same pattern as the blob fills.
struct RadialRevealView: View {

    /// Normalized origin (0…1) relative to the view's bounds.
    /// Falls back to center if nil.
    let origin: CGPoint?
    @Binding var isActive: Bool

    @StateObject private var engine = RevealEngine()

    var body: some View {
        Canvas { context, size in
            guard engine.opacity > 0 else { return }

            let o = origin ?? CGPoint(x: 0.5, y: 0.5)
            let cx = o.x * size.width
            let cy = o.y * size.height

            // Max radius = distance from origin to the farthest corner
            let maxR = [
                CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
                CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height),
            ].map { hypot($0.x - cx, $0.y - cy) }.max() ?? size.width

            let radius = engine.radius * maxR

            let rect = CGRect(x: cx - radius, y: cy - radius,
                              width: radius * 2, height: radius * 2)
            let circle = Path(ellipseIn: rect)

            // Radial gradient: solid center → soft transparent edge
            let gradient = Gradient(stops: [
                .init(color: .white.opacity(engine.opacity), location: 0.0),
                .init(color: .white.opacity(engine.opacity * 0.6), location: 0.7),
                .init(color: .white.opacity(0), location: 1.0),
            ])

            context.fill(circle, with: .radialGradient(
                gradient,
                center: CGPoint(x: cx, y: cy),
                startRadius: 0,
                endRadius: radius
            ))
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active { engine.start() }
        }
    }
}

// MARK: - Engine

private class RevealEngine: ObservableObject {

    /// 0…1 — how far the circle has expanded
    @Published var radius: CGFloat = 0
    /// 0…1 — overall brightness
    @Published var opacity: CGFloat = 0

    private var displayLink: CADisplayLink?
    private var linkTarget: DisplayLinkTarget?
    private var startTime: Date = .now

    // Timing
    private let expandDuration: TimeInterval = 0.7
    private let holdDuration: TimeInterval = 0.15
    private let fadeDuration: TimeInterval = 0.6
    private var totalDuration: TimeInterval { expandDuration + holdDuration + fadeDuration }

    func start() {
        radius = 0
        opacity = 0
        startTime = .now
        startLoop()
    }

    private func startLoop() {
        guard displayLink == nil else { return }
        let target = DisplayLinkTarget { [weak self] in self?.tick() }
        linkTarget = target
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
        linkTarget = nil
        radius = 0
        opacity = 0
    }

    private func tick() {
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > totalDuration {
            stopLoop()
            return
        }

        if elapsed < expandDuration {
            // Phase 1: expand circle, fade in
            let t = elapsed / expandDuration
            let eased = 1.0 - (1.0 - t) * (1.0 - t) // ease-out quadratic
            radius = eased
            // Quick fade in over first 30%
            opacity = min(t / 0.3, 1.0) * 0.55
        } else if elapsed < expandDuration + holdDuration {
            // Phase 2: hold at full size
            radius = 1.0
            opacity = 0.55
        } else {
            // Phase 3: fade out
            let fadeElapsed = elapsed - expandDuration - holdDuration
            let t = fadeElapsed / fadeDuration
            let eased = t * t // ease-in quadratic — slow start, quick finish
            radius = 1.0
            opacity = 0.55 * (1.0 - eased)
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - DisplayLink Bridge

private class DisplayLinkTarget {
    let callback: () -> Void
    init(callback: @escaping () -> Void) { self.callback = callback }
    @objc func tick() { callback() }
}
