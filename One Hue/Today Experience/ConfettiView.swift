import SwiftUI
import Combine

/// Burst of color-matched confetti particles on artwork completion.
/// Uses CADisplayLink for smooth 60fps animation matching the blob-fill pattern.
struct ConfettiView: View {

    let colors: [Color]
    @Binding var isActive: Bool

    @StateObject private var engine = ConfettiEngine()

    var body: some View {
        Canvas { context, size in
            for particle in engine.particles {
                let cx = particle.x * size.width
                let cy = particle.y * size.height
                let w = particle.size
                let h = particle.isCircle ? particle.size : particle.size * 0.6

                var ctx = context
                ctx.opacity = particle.opacity
                ctx.translateBy(x: cx, y: cy)
                ctx.rotate(by: .radians(particle.rotation))

                let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                let path = particle.isCircle
                    ? Path(ellipseIn: rect)
                    : Path(roundedRect: rect, cornerRadius: 1.5)
                ctx.fill(path, with: .color(particle.color))
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if active {
                engine.burst(colors: colors)
            }
        }
    }
}

// MARK: - Particle

private struct Particle {
    var x: CGFloat          // 0…1 normalized
    var y: CGFloat          // 0…1 normalized
    var vx: CGFloat         // velocity x per second
    var vy: CGFloat         // velocity y per second
    var size: CGFloat       // points
    var rotation: Double    // radians
    var rotationSpeed: Double
    var opacity: Double
    var color: Color
    var isCircle: Bool
}

// MARK: - Engine

private class ConfettiEngine: ObservableObject {

    @Published var particles: [Particle] = []

    private var displayLink: CADisplayLink?
    private var linkTarget: DisplayLinkTarget?
    private var startTime: Date = .now
    private let duration: TimeInterval = 2.8

    func burst(colors: [Color]) {
        guard !colors.isEmpty else { return }

        var newParticles: [Particle] = []
        let count = 80

        for _ in 0..<count {
            let angle = Double.random(in: 0 ..< .pi * 2)
            let speed = CGFloat.random(in: 0.3...0.9)
            let color = colors.randomElement() ?? .white

            newParticles.append(Particle(
                x: 0.5,
                y: 0.45,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed - 0.4,   // upward bias
                size: CGFloat.random(in: 4...10),
                rotation: Double.random(in: 0 ..< .pi * 2),
                rotationSpeed: Double.random(in: -6...6),
                opacity: 1.0,
                color: color,
                isCircle: Bool.random()
            ))
        }

        particles = newParticles
        startTime = .now
        startLoop()
    }

    private func startLoop() {
        guard displayLink == nil else { return }
        let target = DisplayLinkTarget { [weak self] in
            self?.tick()
        }
        linkTarget = target
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
        linkTarget = nil
        particles = []
    }

    private func tick() {
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > duration {
            stopLoop()
            return
        }

        let dt: CGFloat = 1.0 / 60.0
        let gravity: CGFloat = 1.2
        let fadeStart = duration * 0.6

        for i in particles.indices {
            particles[i].vy += gravity * dt
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            particles[i].rotation += particles[i].rotationSpeed * dt

            // Fade out in the last 40%
            if elapsed > fadeStart {
                let fadeProgress = (elapsed - fadeStart) / (duration - fadeStart)
                particles[i].opacity = max(0, 1.0 - fadeProgress)
            }
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
