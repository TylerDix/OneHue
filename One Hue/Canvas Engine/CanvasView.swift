import SwiftUI
import UIKit
import QuartzCore

// MARK: - Fill Animation Model

/// Represents one blob-fill animation expanding from a tap point.
struct FillAnimation {
    let origin: CGPoint        // tap point in SVG space
    let startTime: Date
    let maxRadius: CGFloat     // distance to farthest element corner
    let elementIndices: Set<Int>
}

// MARK: - CanvasView

struct CanvasView: View {
    @ObservedObject var store: ColoringStore
    @Binding var lastTapNormalized: CGPoint?
    @Environment(\.scenePhase) private var scenePhase

    // Zoom + pan
    @State private var currentZoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat    = 1.0
    @State private var offset: CGSize       = .zero
    @State private var lastOffset: CGSize   = .zero

    // Viewport tracking
    @State private var viewportSize: CGSize = .zero
    @State private var currentRenderSize: CGSize = .zero

    // Gesture state
    @State private var isZooming: Bool = false

    // Zoom momentum tracking
    @State private var lastZoomTime: Date = .distantPast
    @State private var zoomVelocity: CGFloat = 0  // multiplier per second

    // Phase animation
    @State private var showNumbers: Bool = true
    @State private var strokeDissolve: CGFloat = 1.0

    // Blob fill animation
    @State private var activeAnimations: [FillAnimation] = []
    @State private var flashTick: UInt = 0
    @State private var blobOrigin: CGPoint? = nil
    @State private var animationLink: CADisplayLink?
    @State private var animationTarget: DisplayLinkTarget?

    // Pulse guide — breathing glow on largest unfilled cluster
    @State private var pulsePhase: Double = 0
    @State private var pulseTimer: Timer?

    // "Pick a color" nudge
    @State private var showColorNudge: Bool = false

    // Peek wobble — hints that panning exists on first 3 artworks only
    @State private var hasWobbled: Bool = false
    @AppStorage("onehue.wobbleCount") private var wobbleCount: Int = 0

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 8.0
    /// Soft limits allow temporary overshoot during pinch for rubbery feel.
    private var softMinZoom: CGFloat { minZoom * 0.4 }
    private var softMaxZoom: CGFloat { maxZoom * 1.5 }
    private static let isIPad = UIDevice.current.userInterfaceIdiom == .pad
    /// iPad starts slightly zoomed so artwork fills the large screen and requires panning.
    private var defaultZoom: CGFloat { 1.0 }

    private var contentOverflows: Bool {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return false }
        return currentRenderSize.width * currentZoom > viewportSize.width + 1 ||
               currentRenderSize.height * currentZoom > viewportSize.height + 1
    }

    var body: some View {
        GeometryReader { geo in
            let renderSize = renderedSize(in: geo.size)

            ZStack {
                // SVG Canvas
                SVGCanvasRenderer(
                    document: store.document,
                    filledElements: store.filledElements,
                    selectedGroupIndex: store.selectedGroupIndex,
                    showNumbers: showNumbers,
                    isPeeking: store.isPeeking,
                    zoomLevel: currentZoom / defaultZoom,
                    activeAnimations: activeAnimations,
                    flashTick: flashTick,
                    pulsePhase: pulsePhase,
                    strokeDissolve: strokeDissolve
                )
                .frame(width: renderSize.width, height: renderSize.height)

            }
            .frame(width: renderSize.width, height: renderSize.height)
            .scaleEffect(currentZoom)
            .offset(offset)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(paintGesture(viewportSize: geo.size, renderSize: renderSize))
            .simultaneousGesture(zoomGesture)
            .simultaneousGesture(panGesture)
            .onAppear {
                viewportSize = geo.size
                currentRenderSize = renderSize
                #if DEBUG
                pushDebugInfo()
                #endif
                peekWobbleIfNeeded()
            }
            .onChange(of: geo.size) { _, newSize in
                viewportSize = newSize
                currentRenderSize = renderedSize(in: newSize)
                #if DEBUG
                pushDebugInfo()
                #endif
            }
            .onChange(of: store.document.id) { _, _ in
                currentRenderSize = renderedSize(in: geo.size)
                // Reset zoom/pan for the new artwork
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentZoom = defaultZoom; lastZoom = defaultZoom
                    offset = .zero; lastOffset = .zero
                }
                hasWobbled = false
                peekWobbleIfNeeded()
                #if DEBUG
                pushDebugInfo()
                #endif
            }
        }
        .clipped()
        .overlay(alignment: .bottom) {
            if showColorNudge {
                Text("Tap a color below")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(.black.opacity(0.35))
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    )
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: store.phase) { _, phase in animate(to: phase) }
        .onChange(of: store.completionDriftToken) { _, token in
            guard token > 0 else { return }
            slowDriftToCenter()
        }
        .onChange(of: store.findTargetToken) { _, token in
            guard token > 0 else { return }
            zoomToRect(store.findTargetBounds)
        }
        .onChange(of: store.resetZoomTrigger) { _, _ in
            resetZoom()
        }
        .onChange(of: store.filledElements) { oldValue, newValue in
            let added = newValue.subtracting(oldValue)
            guard !added.isEmpty else { return }

            // Blob animation
            if let origin = blobOrigin {
                let maxRadius = blobMaxRadius(from: origin, elements: added)
                let animation = FillAnimation(
                    origin: origin,
                    startTime: Date(),
                    maxRadius: maxRadius,
                    elementIndices: added
                )
                activeAnimations.append(animation)
                startAnimationLoop()
                blobOrigin = nil
            }

            // If the selected group just dropped to few remaining, kick into
            // continuous pulse mode so stragglers are easy to find
            if let selIdx = store.selectedGroupIndex, selIdx < store.document.groups.count {
                let group = store.document.groups[selIdx]
                let remaining = group.elementIndices.filter { !newValue.contains($0) }.count
                if remaining > 0 && remaining <= 5 && pulseTimer == nil {
                    startPulse()
                }
            }
        }
        .onChange(of: store.selectedGroupIndex) { _, _ in startPulse() }
        .onChange(of: store.pulseTrigger) { _, _ in startPulse() }
        .onAppear {
            animate(to: store.phase)
            startPulse()
        }
        .onDisappear {
            stopAnimationLoop()
            pulseTimer?.invalidate(); pulseTimer = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                startPulse()
            } else {
                pulseTimer?.invalidate(); pulseTimer = nil
                pulsePhase = 0
            }
        }
    }

    // MARK: - Phase Animation

    private func animate(to phase: ArtworkPhase) {
        switch phase {
        case .painting:
            strokeDissolve = 1.0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                showNumbers = true
                currentZoom = defaultZoom; lastZoom = defaultZoom
                offset = .zero; lastOffset = .zero
            }

        case .complete:
            withAnimation(.easeOut(duration: 1.0)) { showNumbers = false }
            withAnimation(.easeOut(duration: 1.2)) { strokeDissolve = 0.0 }
        }
    }

    // MARK: - Paint Gesture

    /// Tap-or-pan: fills happen on finger-lift only if the finger didn't travel far.
    /// This prevents accidental fills when the user intends to drag/pan.
    /// Set true once we schedule a fill; reset on onEnded.
    /// Set true when finger has moved enough to be a pan, cancelling any pending fill.
    @State private var gestureIsPan: Bool = false
    /// Stash tap location so we can fill on onEnded if it wasn't a pan.
    @State private var pendingFillLocation: CGPoint? = nil

    /// Points of travel before we consider it a pan and cancel the pending fill.
    private static let panThreshold: CGFloat = 6

    private func paintGesture(viewportSize: CGSize, renderSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Track movement — if the finger travels far, it's a pan
                let dist = hypot(value.translation.width, value.translation.height)
                if dist > Self.panThreshold {
                    gestureIsPan = true
                    pendingFillLocation = nil  // cancel any pending fill
                    if contentOverflows {
                        // Allow panning with rubber-band at edges
                        let rawX = lastOffset.width  + value.translation.width
                        let rawY = lastOffset.height + value.translation.height
                        let maxX = max(0, (currentRenderSize.width * currentZoom - viewportSize.width) / 2)
                        let maxY = max(0, (currentRenderSize.height * currentZoom - viewportSize.height) / 2)
                        withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.7)) {
                            offset = CGSize(
                                width:  Self.rubberBand(rawX, limit: maxX),
                                height: Self.rubberBand(rawY, limit: maxY)
                            )
                        }
                    }
                }

                // Stash first touch location for fill-on-release
                if pendingFillLocation == nil, !gestureIsPan {
                    pendingFillLocation = value.location
                }
            }
            .onEnded { _ in
                let wasPan = gestureIsPan
                let fillLoc = pendingFillLocation
                gestureIsPan = false
                pendingFillLocation = nil

                if wasPan {
                    // Snap back from rubber-band overshoot
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                        clampOffsetValues()
                        lastOffset = offset
                    }
                } else {
                    lastOffset = offset
                    // Fill on lift — only if it wasn't a pan or zoom
                    if let loc = fillLoc,
                       !isZooming,
                       store.phase == .painting,
                       !store.isPeeking {
                        attemptFill(at: loc, viewportSize: viewportSize, renderSize: renderSize)
                    }
                }
            }
    }

    private func attemptFill(at loc: CGPoint, viewportSize: CGSize, renderSize: CGSize) {
        guard let selected = store.selectedGroupIndex else {
            // Nudge user to pick a color first
            if !showColorNudge {
                withAnimation(.easeInOut(duration: 0.25)) { showColorNudge = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeInOut(duration: 0.4)) { showColorNudge = false }
                }
            }
            return
        }

        // Try exact hit
        if let hit = screenToElement(loc, viewportSize: viewportSize, renderSize: renderSize) {
            let groupIdx = store.document.elementGroupMap[hit.elementIndex] ?? -1
            let isCorrect = groupIdx == selected
            let needsFill = !store.filledElements.contains(hit.elementIndex)

            if isCorrect && needsFill {
                blobOrigin = hit.svgPoint
                lastTapNormalized = CGPoint(x: loc.x / viewportSize.width,
                                            y: loc.y / viewportSize.height)
                store.tryFill(elementIndex: hit.elementIndex)
                return
            }
        }

        // Exact hit missed or wrong color — try color snap
        let svg = screenToSVGPoint(loc, viewportSize: viewportSize, renderSize: renderSize)
        if let snapIdx = colorSnapHit(svgPoint: svg, selectedGroup: selected) {
            blobOrigin = svg
            lastTapNormalized = CGPoint(x: loc.x / viewportSize.width,
                                        y: loc.y / viewportSize.height)
            store.tryFill(elementIndex: snapIdx)
        }
    }

    // MARK: - Hit Testing

    /// How far (in SVG units) to search for a nearby element when the
    /// exact tap misses. Scales with zoom so it feels consistent on screen.
    private static let tapMarginBase: CGFloat = 50

    /// How far (in SVG units) to search for a same-color unfilled element
    /// when the exact tap misses or hits a wrong-color element.
    private static let colorSnapRadiusBase: CGFloat = 50

    /// Transform a screen point (in viewport space) to SVG coordinate space.
    private func screenToSVGPoint(_ point: CGPoint, viewportSize: CGSize, renderSize: CGSize) -> CGPoint {
        let vcx = viewportSize.width / 2
        let vcy = viewportSize.height / 2
        let dx = (point.x - vcx - offset.width) / currentZoom
        let dy = (point.y - vcy - offset.height) / currentZoom
        let canvasX = dx + renderSize.width / 2
        let canvasY = dy + renderSize.height / 2

        let vb = store.document.viewBox
        let scale = min(renderSize.width / vb.width, renderSize.height / vb.height)
        let svgOffsetX = (renderSize.width - vb.width * scale) / 2
        let svgOffsetY = (renderSize.height - vb.height * scale) / 2

        return CGPoint(x: (canvasX - svgOffsetX) / scale + vb.origin.x,
                       y: (canvasY - svgOffsetY) / scale + vb.origin.y)
    }

    private func screenToElement(_ point: CGPoint, viewportSize: CGSize, renderSize: CGSize) -> (elementIndex: Int, svgPoint: CGPoint)? {
        let svgPoint = screenToSVGPoint(point, viewportSize: viewportSize, renderSize: renderSize)
        let svgX = svgPoint.x
        let svgY = svgPoint.y

        // 1. Exact path hit — topmost element wins
        let candidates = store.spatialHash.candidates(at: svgPoint)
        for idx in candidates.reversed() {
            let element = store.document.elements[idx]
            guard element.bounds.contains(svgPoint) else { continue }
            if element.path.contains(svgPoint) {
                return (idx, svgPoint)
            }
        }

        // 2. Cluster label hit — tapping on/near a number label fills
        //    the nearest unfilled element in that cluster.
        var bestLabelIdx: Int?
        var bestLabelDist: CGFloat = .greatestFiniteMagnitude

        for cluster in store.document.clusters {
            let hasUnfilled = cluster.elementIndices.contains { !store.filledElements.contains($0) }
            guard hasUnfilled else { continue }

            let cdx = svgPoint.x - cluster.labelCenter.x
            let cdy = svgPoint.y - cluster.labelCenter.y
            let dist = hypot(cdx, cdy)

            // Hit radius based on label font size (generous for easy tapping)
            // Matches the boosted minimum from the rendering pass so
            // pill-backed labels are as easy to tap as they look.
            let dim = min(cluster.bounds.width, cluster.bounds.height)
            let isSelectedCluster = store.selectedGroupIndex.map { cluster.groupIndex == $0 } ?? false
            let fontSize = max(min(dim * 0.35, 60), isSelectedCluster ? 24 : 10)
            let hitRadius = max(fontSize * 1.2, 30)

            if dist < hitRadius, dist < bestLabelDist {
                bestLabelDist = dist
                // Pick nearest unfilled element in the cluster
                if let nearest = cluster.elementIndices
                    .filter({ !store.filledElements.contains($0) })
                    .min(by: {
                        let ea = store.document.elements[$0]
                        let eb = store.document.elements[$1]
                        return hypot(ea.centroid.x - svgX, ea.centroid.y - svgY)
                             < hypot(eb.centroid.x - svgX, eb.centroid.y - svgY)
                    }) {
                    bestLabelIdx = nearest
                }
            }
        }

        if let idx = bestLabelIdx {
            return (idx, svgPoint)
        }

        // 3. Fuzzy nearby element — use distance to bounding box edge
        //    (not centroid) for better results near element borders.
        //    Prefer larger elements over tiny specks when both are nearby.
        let margin = Self.tapMarginBase / max(currentZoom, 0.5)
        let searchRect = CGRect(x: svgX - margin, y: svgY - margin,
                                width: margin * 2, height: margin * 2)

        let tinyThresh = ColoringStore.tinyThresholdMax
        var bestIdx: Int?
        var bestDist: CGFloat = .greatestFiniteMagnitude
        var bestNonTinyIdx: Int?
        var bestNonTinyDist: CGFloat = .greatestFiniteMagnitude

        let expanded = store.spatialHash.candidates(in: searchRect)
        for idx in expanded {
            let el = store.document.elements[idx]
            let b = el.bounds
            // Distance from tap to nearest edge of bounding box
            let nearX = max(b.minX, min(svgX, b.maxX))
            let nearY = max(b.minY, min(svgY, b.maxY))
            let edgeDx = svgX - nearX
            let edgeDy = svgY - nearY
            let dist = edgeDx * edgeDx + edgeDy * edgeDy
            if dist < bestDist {
                bestDist = dist
                bestIdx = idx
            }
            if min(b.width, b.height) >= tinyThresh, dist < bestNonTinyDist {
                bestNonTinyDist = dist
                bestNonTinyIdx = idx
            }
        }

        // If the closest match is tiny but a non-tiny element is within 2× the
        // distance, prefer the larger element — avoids frustrating speck taps.
        if let tinyIdx = bestIdx, let nonTinyIdx = bestNonTinyIdx, tinyIdx != nonTinyIdx {
            let isTiny = min(store.document.elements[tinyIdx].bounds.width,
                             store.document.elements[tinyIdx].bounds.height) < tinyThresh
            if isTiny, bestNonTinyDist < bestDist * 4 { // 4× squared distance = 2× linear
                bestIdx = nonTinyIdx
                bestDist = bestNonTinyDist
            }
        }

        if let idx = bestIdx, bestDist < margin * margin {
            return (idx, svgPoint)
        }
        return nil
    }

    /// Color-aware snap: finds the nearest unfilled element belonging to the
    /// currently selected color group within a generous radius. Uses spatial
    /// hash for performance — never iterates all document elements.
    private func colorSnapHit(svgPoint: CGPoint, selectedGroup: Int) -> Int? {
        guard selectedGroup < store.document.groups.count else { return nil }
        let group = store.document.groups[selectedGroup]
        let groupSet = Set(group.elementIndices)

        let snapRadius = Self.colorSnapRadiusBase / max(currentZoom, 0.5)
        let searchRect = CGRect(x: svgPoint.x - snapRadius,
                                y: svgPoint.y - snapRadius,
                                width: snapRadius * 2,
                                height: snapRadius * 2)
        let snapRadiusSq = snapRadius * snapRadius

        var bestIdx: Int?
        var bestDistSq: CGFloat = .greatestFiniteMagnitude

        for idx in store.spatialHash.candidates(in: searchRect) {
            guard groupSet.contains(idx),
                  !store.filledElements.contains(idx) else { continue }

            let b = store.document.elements[idx].bounds
            let nearX = max(b.minX, min(svgPoint.x, b.maxX))
            let nearY = max(b.minY, min(svgPoint.y, b.maxY))
            let dx = svgPoint.x - nearX
            let dy = svgPoint.y - nearY
            let distSq = dx * dx + dy * dy

            guard distSq < snapRadiusSq, distSq < bestDistSq else { continue }
            bestDistSq = distSq
            bestIdx = idx
        }
        return bestIdx
    }

    // MARK: - Pan / Zoom

    private func panIfNeeded(value: DragGesture.Value) {
        guard contentOverflows else { return }
        offset = CGSize(
            width:  lastOffset.width  + value.translation.width,
            height: lastOffset.height + value.translation.height
        )
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isZooming {
                    isZooming = true
                    zoomVelocity = 0
                    lastZoomTime = .now
                }
                // Allow overshoot past limits (rubber-band), clamped to soft limits
                let rawZoom = lastZoom * value
                let newZoom = min(max(rawZoom, softMinZoom), softMaxZoom)

                // Track zoom velocity (ratio change per second)
                let now = Date.now
                let dt = now.timeIntervalSince(lastZoomTime)
                if dt > 0.01, currentZoom > 0.01 {
                    let instantVelocity = (newZoom / currentZoom - 1.0) / dt
                    zoomVelocity = zoomVelocity * 0.3 + instantVelocity * 0.7
                }
                lastZoomTime = now

                // Interpolated zoom — slight lag before visual response for deliberate feel
                withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.75)) {
                    if currentZoom > 0.01 {
                        let scale = newZoom / currentZoom
                        offset = CGSize(
                            width:  offset.width  * scale,
                            height: offset.height * scale
                        )
                    }
                    currentZoom = newZoom
                }
            }
            .onEnded { _ in
                // Apply momentum: project zoom forward based on velocity
                let momentumDuration: CGFloat = 0.5
                var projectedZoom = currentZoom * (1.0 + zoomVelocity * momentumDuration)
                // Clamp to hard limits
                projectedZoom = min(max(projectedZoom, minZoom), maxZoom)

                let scale = projectedZoom / max(currentZoom, 0.01)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.58)) {
                    offset = CGSize(
                        width:  offset.width  * scale,
                        height: offset.height * scale
                    )
                    currentZoom = projectedZoom
                }

                lastZoom = projectedZoom
                lastOffset = offset
                zoomVelocity = 0

                // Clamp offset after spring settles
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    clampOffset()
                }

                // Brief delay before re-enabling fills to prevent accidental
                // fill from finger lift at the end of a pinch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isZooming = false
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard contentOverflows else { return }
                let rawX = lastOffset.width  + value.translation.width
                let rawY = lastOffset.height + value.translation.height

                // Rubber-band: allow overshoot past edges with resistance
                let maxX = max(0, (currentRenderSize.width * currentZoom - viewportSize.width) / 2)
                let maxY = max(0, (currentRenderSize.height * currentZoom - viewportSize.height) / 2)
                withAnimation(.interactiveSpring(response: 0.08, dampingFraction: 0.7)) {
                    offset = CGSize(
                        width:  Self.rubberBand(rawX, limit: maxX),
                        height: Self.rubberBand(rawY, limit: maxY)
                    )
                }
            }
            .onEnded { _ in
                lastOffset = offset
                // Snap back from rubber-band overshoot
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                    clampOffsetValues()
                    lastOffset = offset
                }
            }
    }

    /// Rubber-band effect: past the limit, displacement is attenuated logarithmically.
    private static func rubberBand(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        let clamped = min(max(value, -limit), limit)
        if abs(value) <= limit { return value }
        let overshoot = abs(value) - limit
        let dampened = limit + overshoot / (1.0 + overshoot / 200.0)
        return value > 0 ? dampened : -dampened
    }

    // MARK: - Layout

    private func renderedSize(in available: CGSize) -> CGSize {
        let aspect = store.document.aspectRatio
        let hByWidth  = available.width / aspect
        let wByHeight = available.height * aspect
        if hByWidth >= available.height {
            return CGSize(width: available.width, height: hByWidth)
        }
        return CGSize(width: wByHeight, height: available.height)
    }

    /// Clamp offset values without animation — call inside withAnimation blocks.
    private func clampOffsetValues() {
        let maxX = max(0, (currentRenderSize.width * currentZoom - viewportSize.width) / 2)
        let maxY = max(0, (currentRenderSize.height * currentZoom - viewportSize.height) / 2)
        offset.width  = min(max(offset.width,  -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    /// Hard clamp during active drag — no animation, no rubber-banding.
    private func clampOffsetImmediate() {
        let maxX = max(0, (currentRenderSize.width * currentZoom - viewportSize.width) / 2)
        let maxY = max(0, (currentRenderSize.height * currentZoom - viewportSize.height) / 2)
        offset.width  = min(max(offset.width,  -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
        #if DEBUG
        pushDebugInfo()
        #endif
    }

    /// Animated clamp for zoom end — gentle settle after pinch release.
    private func clampOffset() {
        let maxX = max(0, (currentRenderSize.width * currentZoom - viewportSize.width) / 2)
        let maxY = max(0, (currentRenderSize.height * currentZoom - viewportSize.height) / 2)
        withAnimation(.easeOut(duration: 0.15)) {
            offset.width  = min(max(offset.width,  -maxX), maxX)
            offset.height = min(max(offset.height, -maxY), maxY)
            lastOffset = offset
        }
        #if DEBUG
        pushDebugInfo()
        #endif
    }

    /// Distance from origin to farthest bounding-box corner of the given elements.
    private func blobMaxRadius(from origin: CGPoint, elements: Set<Int>) -> CGFloat {
        var maxDist: CGFloat = 0
        for idx in elements {
            let bounds = store.document.elements[idx].bounds
            for corner in [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.minX, y: bounds.maxY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
            ] {
                maxDist = max(maxDist, hypot(corner.x - origin.x, corner.y - origin.y))
            }
        }
        return maxDist
    }

    #if DEBUG
    private func pushDebugInfo() {
        store.canvasDebug = .init(
            viewportSize: viewportSize,
            renderSize: currentRenderSize,
            zoom: currentZoom,
            offset: offset,
            contentOverflows: contentOverflows
        )
    }
    #endif

    /// Horizontal wobble to hint that the canvas is pannable.
    /// Fires every time an artwork is opened.
    private func peekWobbleIfNeeded() {
        guard !hasWobbled, wobbleCount < 3 else { return }
        hasWobbled = true
        wobbleCount += 1

        let drift: CGFloat = 18
        // Slight delay so the artwork is fully visible first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                offset.width = drift
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    offset.width = -drift
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
        }
    }

    private func resetZoom(to zoom: CGFloat? = nil) {
        let z = zoom ?? 1.0
        withAnimation(.easeInOut(duration: 0.3)) {
            currentZoom = z; lastZoom = z
            offset = .zero; lastOffset = .zero
        }
    }

    /// Slowly drifts back to center — called after the completion freeze.
    private func slowDriftToCenter() {
        withAnimation(.easeInOut(duration: 1.5)) {
            currentZoom = 1.0; lastZoom = 1.0
            offset = .zero; lastOffset = .zero
        }
    }

    // MARK: - Animation Loop

    /// Starts a CADisplayLink-driven loop for blob animations. Runs at display
    /// refresh rate and automatically stops when all animations finish.
    private func startAnimationLoop() {
        guard animationLink == nil else { return }
        let target = DisplayLinkTarget { [self] in
            // Tick the Canvas redraw
            flashTick &+= 1

            // Prune finished animations (0.6s blob + 0.1s margin)
            let now = Date()
            activeAnimations.removeAll { now.timeIntervalSince($0.startTime) > 0.7 }

            if activeAnimations.isEmpty {
                stopAnimationLoop()
            }
        }
        animationTarget = target
        let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick))
        link.add(to: .main, forMode: .common)
        animationLink = link
    }

    private func stopAnimationLoop() {
        animationLink?.invalidate()
        animationLink = nil
        animationTarget = nil
    }

    // MARK: - Pulse Guide

    /// Starts a breathing glow on the largest unfilled cluster.
    /// Runs for 3 seconds normally, or indefinitely when few pieces remain
    /// (the "where are the stragglers?" mode).
    private func startPulse() {
        pulseTimer?.invalidate()
        pulsePhase = 0

        // Check if the selected group is nearly done — if so, pulse indefinitely
        let nearlyDone: Bool = {
            guard let selIdx = store.selectedGroupIndex, selIdx < store.document.groups.count else { return false }
            let group = store.document.groups[selIdx]
            let remaining = group.elementIndices.filter { !store.filledElements.contains($0) }.count
            return remaining > 0 && remaining <= 5
        }()

        // ~30 fps
        var ticks = 0
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [self] timer in
            ticks += 1
            Task { @MainActor in
                pulsePhase = Double(ticks) / 30.0  // seconds elapsed
                // 3-second pulse normally; indefinite when nearly done
                if !nearlyDone && ticks >= 90 {
                    timer.invalidate()
                    pulseTimer = nil
                    pulsePhase = 0
                }
            }
        }
    }

    // MARK: - Find / Zoom-to-Target

    /// Smoothly zooms and pans to center the given SVG-space rect in the viewport.
    private func zoomToRect(_ svgRect: CGRect) {
        let renderSize = currentRenderSize
        guard viewportSize.width > 0, viewportSize.height > 0,
              renderSize.width > 0, renderSize.height > 0 else { return }

        let vb = store.document.viewBox
        let scale = min(renderSize.width / vb.width, renderSize.height / vb.height)
        let svgOffsetX = (renderSize.width - vb.width * scale) / 2
        let svgOffsetY = (renderSize.height - vb.height * scale) / 2

        // Pad the target rect so the cluster isn't jammed to the edge
        let padded = svgRect.insetBy(dx: -svgRect.width * 0.8, dy: -svgRect.height * 0.8)

        // Zoom level that fits the padded rect in the viewport
        let clusterW = max(padded.width * scale, 1)
        let clusterH = max(padded.height * scale, 1)
        let fitZoom = min(viewportSize.width / clusterW, viewportSize.height / clusterH)
        let targetZoom = min(max(fitZoom, 3.0), maxZoom)

        // Offset to center the cluster
        let canvasX = (svgRect.midX - vb.origin.x) * scale + svgOffsetX
        let canvasY = (svgRect.midY - vb.origin.y) * scale + svgOffsetY
        let dx = canvasX - renderSize.width / 2
        let dy = canvasY - renderSize.height / 2

        // Clamp so the offset can't scroll past canvas edges into black
        let maxX = max(0, (renderSize.width * targetZoom - viewportSize.width) / 2)
        let maxY = max(0, (renderSize.height * targetZoom - viewportSize.height) / 2)
        let newOffset = CGSize(
            width:  min(max(-dx * targetZoom, -maxX), maxX),
            height: min(max(-dy * targetZoom, -maxY), maxY)
        )

        withAnimation(.easeInOut(duration: 0.45)) {
            currentZoom = targetZoom
            lastZoom = targetZoom
            offset = newOffset
            lastOffset = newOffset
        }
    }
}

// MARK: - SVG Canvas Renderer

struct SVGCanvasRenderer: View {
    let document: SVGDocument
    let filledElements: Set<Int>
    let selectedGroupIndex: Int?
    let showNumbers: Bool
    let isPeeking: Bool
    let zoomLevel: CGFloat
    let activeAnimations: [FillAnimation]
    let flashTick: UInt  // drives re-renders during blob animation
    let pulsePhase: Double  // 0 = no pulse, >0 = seconds into breathing animation
    let strokeDissolve: CGFloat  // 1.0 = visible boundary lines, 0.0 = dissolved (seamless art)

    private static let blobDuration: TimeInterval = 0.6

    // MARK: - Checkerboard Tiles

    /// Dense 6-SVG-unit checkerboard (4× tighter than before).
    /// Two variants so the pattern pops on any background color.
    private static func makeCheckerImage(r: CGFloat, g: CGFloat, b: CGFloat, alpha: CGFloat) -> Image {
        let cell = 6
        let size = cell * 2
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Image(systemName: "checkerboard.rectangle") }
        ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: alpha))
        ctx.fill(CGRect(x: 0, y: 0, width: cell, height: cell))
        ctx.fill(CGRect(x: cell, y: cell, width: cell, height: cell))
        guard let cgImage = ctx.makeImage() else { return Image(systemName: "checkerboard.rectangle") }
        return Image(decorative: cgImage, scale: 1)
    }

    /// Light checker (white squares) — for dark group colors
    private static let checkerImageLight = makeCheckerImage(r: 1, g: 1, b: 1, alpha: 0.18)
    /// Dark checker (dark gray squares) — for light/white group colors
    private static let checkerImageDark  = makeCheckerImage(r: 0, g: 0, b: 0, alpha: 0.22)

    /// Returns true when a color is light enough that white overlays would be invisible.
    /// Cached to avoid UIColor HSB conversion every frame.
    private static var lightColorCache: [Int: Bool] = [:]
    private static func isLightColor(_ color: Color) -> Bool {
        let key = color.hashValue
        if let cached = lightColorCache[key] { return cached }
        let ui = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let result = b > 0.75 && s < 0.35
        lightColorCache[key] = result
        return result
    }

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            let vb = document.viewBox
            let scaleX = size.width / vb.width
            let scaleY = size.height / vb.height
            let scale = min(scaleX, scaleY)

            var ctx = context
            // Slight over-scale to hide any residual edge artifacts from Image Trace exports
            let overScale: CGFloat = 1.012
            let adjScale = scale * overScale
            let adjOffsetX = (size.width - vb.width * adjScale) / 2
            let adjOffsetY = (size.height - vb.height * adjScale) / 2
            ctx.translateBy(x: adjOffsetX, y: adjOffsetY)
            ctx.scaleBy(x: adjScale, y: adjScale)
            ctx.translateBy(x: -vb.origin.x, y: -vb.origin.y)

            let now = Date()

            // Hairline stroke style to close sub-pixel gaps between adjacent paths
            let gapStroke = StrokeStyle(lineWidth: 0.4, lineJoin: .round)

            // Pre-compute muted colors once per frame (avoids UIColor HSB conversion per element)
            var mutedSel: [Int: Color] = [:]
            var mutedOther: [Int: Color] = [:]
            var mutedOverview: [Int: Color] = [:]
            let noSelection = selectedGroupIndex == nil
            for group in document.groups {
                mutedSel[group.id] = Self.computeMuted(group.color, selected: true)
                mutedOther[group.id] = Self.computeMuted(group.color, selected: false)
                if noSelection {
                    mutedOverview[group.id] = Self.computeMutedOverview(group.color)
                }
            }

            // Build element→animation lookup once per frame (avoids O(n×m) scan)
            var animByElement: [Int: FillAnimation] = [:]
            for anim in activeAnimations {
                for idx in anim.elementIndices {
                    animByElement[idx] = anim
                }
            }

            // Pass 1: Fill all elements (with blob reveal for active animations)
            for element in document.elements {
                let isFilled = isPeeking || filledElements.contains(element.id)
                guard let groupIdx = document.elementGroupMap[element.id],
                      groupIdx < document.groups.count else {
                    // Ungrouped element (border sliver): render as white, no interaction
                    let path = document.cachedPath(at: element.id)
                    ctx.fill(path, with: .color(.white))
                    continue
                }
                let group = document.groups[groupIdx]
                let path = document.cachedPath(at: element.id)

                // Check if this element is part of an active blob animation
                let anim = animByElement[element.id]

                if isFilled, let anim = anim {
                    // Animating: blob expanding from tap point
                    let elapsed = now.timeIntervalSince(anim.startTime)
                    let t = min(elapsed / Self.blobDuration, 1.0)
                    let easedT = 1.0 - (1.0 - t) * (1.0 - t) // ease-out
                    let currentRadius = easedT * anim.maxRadius

                    // Fast check: is element fully inside the blob?
                    let b = element.bounds
                    let corners = [
                        CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.maxX, y: b.minY),
                        CGPoint(x: b.minX, y: b.maxY), CGPoint(x: b.maxX, y: b.maxY),
                    ]
                    let fullyInside = corners.allSatisfy {
                        hypot($0.x - anim.origin.x, $0.y - anim.origin.y) <= currentRadius
                    }

                    if fullyInside || t >= 1.0 {
                        ctx.fill(path, with: .color(group.color))
                        ctx.stroke(path, with: .color(group.color), style: gapStroke)
                    } else {
                        // Draw muted base, then clip-reveal filled color
                        let isSelected = groupIdx == selectedGroupIndex
                        let muted = (noSelection ? mutedOverview[groupIdx] : (isSelected ? mutedSel[groupIdx] : mutedOther[groupIdx])) ?? .gray
                        ctx.fill(path, with: .color(muted))
                        ctx.stroke(path, with: .color(muted), style: gapStroke)

                        ctx.drawLayer { layerCtx in
                            let circle = Path(ellipseIn: CGRect(
                                x: anim.origin.x - currentRadius,
                                y: anim.origin.y - currentRadius,
                                width: currentRadius * 2,
                                height: currentRadius * 2
                            ))
                            layerCtx.clip(to: circle)
                            layerCtx.fill(path, with: .color(group.color))
                        }
                    }

                } else if isFilled {
                    ctx.fill(path, with: .color(group.color))
                    ctx.stroke(path, with: .color(group.color), style: gapStroke)

                } else {
                    let isSelected = groupIdx == selectedGroupIndex
                    let muted = (noSelection ? mutedOverview[groupIdx] : (isSelected ? mutedSel[groupIdx] : mutedOther[groupIdx])) ?? .gray
                    ctx.fill(path, with: .color(muted))
                    ctx.stroke(path, with: .color(muted), style: gapStroke)
                }
            }

            // Pass 1.25: Coloring-page boundary lines on all grouped elements.
            // Visible during painting, dissolves away on completion to reveal seamless art.
            if strokeDissolve > 0.001 {
                let boundaryWidth: CGFloat = 0.5
                let boundaryStyle = StrokeStyle(lineWidth: boundaryWidth, lineJoin: .round)
                let boundaryOpacity = 0.12 * strokeDissolve
                for element in document.elements {
                    guard document.elementGroupMap[element.id] != nil else { continue }
                    ctx.stroke(document.cachedPath(at: element.id), with: .color(.black.opacity(boundaryOpacity)), style: boundaryStyle)
                }
            }

            // Pass 1.5: Boundary hairlines on unfilled regions.
            // Makes the puzzle readable at first glance — users can see distinct pieces.
            if !isPeeking {
                let hairlineWidth: CGFloat = 0.6
                let hairlineStyle = StrokeStyle(lineWidth: hairlineWidth, lineJoin: .round)
                for element in document.elements {
                    guard !filledElements.contains(element.id) else { continue }
                    guard document.elementGroupMap[element.id] != nil else { continue }
                    let isSelected = document.elementGroupMap[element.id] == selectedGroupIndex
                    let opacity = isSelected ? 0.22 : 0.14
                    ctx.stroke(document.cachedPath(at: element.id), with: .color(.white.opacity(opacity)), style: hairlineStyle)
                }
            }

            // Pass 2 + 2.5: Checkerboard overlay and breathing pulse on selected group's unfilled elements.
            // Combined into one block to avoid building the same path twice.
            if !isPeeking, let selIdx = selectedGroupIndex, selIdx < document.groups.count {
                let selectedGroup = document.groups[selIdx]

                // Build unfilled path once, reuse for both passes
                var unfilledPath = Path()
                for idx in selectedGroup.elementIndices where !filledElements.contains(idx) {
                    unfilledPath.addPath(document.cachedPath(at: idx))
                }

                let light = Self.isLightColor(selectedGroup.color)

                // Pass 2: Dense checkerboard — dark checks on light colors, light on dark
                if showNumbers, !unfilledPath.isEmpty {
                    let checker = light ? Self.checkerImageDark : Self.checkerImageLight
                    ctx.drawLayer { layerCtx in
                        layerCtx.clip(to: unfilledPath)
                        layerCtx.fill(Path(vb), with: .tiledImage(checker))
                    }
                    let strokeColor: Color = light ? .black.opacity(0.18) : .white.opacity(0.15)
                    ctx.stroke(unfilledPath, with: .color(strokeColor), lineWidth: 0.8 / scale)
                }

                // Pass 2.5: Breathing pulse — dark flash for light colors, bright for dark
                if pulsePhase > 0, !unfilledPath.isEmpty {
                    let breath = sin(pulsePhase * .pi * 1.3)
                    let alpha = max(breath, 0) * (light ? 0.35 : 0.55)
                    let pulseColor: Color = light ? .black : selectedGroup.color
                    ctx.fill(unfilledPath, with: .color(pulseColor.opacity(alpha)))
                }
            }

            // Pass 3: Number labels.
            // No color selected → show ONE label per group (largest cluster only)
            // Color selected → show all clusters for that group
            if showNumbers, !isPeeking {
                let showAllGroups = selectedGroupIndex == nil
                let isLargeScreen = UIDevice.current.userInterfaceIdiom == .pad
                let minVisible: CGFloat = showAllGroups ? (isLargeScreen ? 5 : 3) : (isLargeScreen ? 4 : 3)
                let fullVisible: CGFloat = showAllGroups ? (isLargeScreen ? 9 : 6) : (isLargeScreen ? 10 : 8)

                struct LabelInfo {
                    let center: CGPoint
                    let fontSize: CGFloat
                    let alpha: Double
                    let groupNumber: Int
                    let area: CGFloat
                    let needsPill: Bool
                    let isOverview: Bool
                }

                var candidateClusters: [ElementCluster] = []
                if let selIdx = selectedGroupIndex {
                    for cluster in document.clusters {
                        guard cluster.groupIndex == selIdx else { continue }
                        let hasUnfilled = cluster.elementIndices.contains { !filledElements.contains($0) }
                        guard hasUnfilled else { continue }
                        candidateClusters.append(cluster)
                    }
                } else {
                    let minArea: CGFloat = 1500
                    var groupClusters: [Int: [(cluster: ElementCluster, area: CGFloat)]] = [:]
                    for cluster in document.clusters {
                        let hasUnfilled = cluster.elementIndices.contains { !filledElements.contains($0) }
                        guard hasUnfilled else { continue }
                        let area = cluster.bounds.width * cluster.bounds.height
                        guard area >= minArea else { continue }
                        groupClusters[cluster.groupIndex, default: []].append((cluster, area))
                    }
                    for (_, clusters) in groupClusters {
                        let top = clusters.sorted { $0.area > $1.area }.prefix(2)
                        candidateClusters.append(contentsOf: top.map { $0.cluster })
                    }
                }

                var labels: [LabelInfo] = []

                for cluster in candidateClusters {
                    let hasUnfilled = cluster.elementIndices.contains { !filledElements.contains($0) }
                    guard hasUnfilled else { continue }

                    let groupNumber = cluster.groupIndex < document.groups.count
                        ? document.groups[cluster.groupIndex].id + 1
                        : cluster.groupIndex + 1

                    let dim = min(cluster.bounds.width, cluster.bounds.height)
                    let naturalSize: CGFloat
                    let fontSize: CGFloat
                    if isLargeScreen {
                        naturalSize = min(dim * 0.25, showAllGroups ? 36 : 44)
                        fontSize = max(naturalSize, CGFloat(showAllGroups ? 16 : 18))
                    } else {
                        naturalSize = min(dim * 0.35, showAllGroups ? 48 : 60)
                        fontSize = max(naturalSize, CGFloat(showAllGroups ? 20 : 24))
                    }
                    let needsPill = naturalSize < 24

                    // Numbers require zoom to appear — search by color first,
                    // numbers confirm when close.
                    let screenPt = fontSize * scale * zoomLevel
                    guard screenPt >= minVisible else { continue }

                    let sizeAlpha = min((screenPt - minVisible) / (fullVisible - minVisible), 1.0)
                    let area = cluster.bounds.width * cluster.bounds.height

                    labels.append(LabelInfo(
                        center: cluster.labelCenter,
                        fontSize: fontSize,
                        alpha: 0.9 * sizeAlpha,
                        groupNumber: groupNumber,
                        area: area,
                        needsPill: needsPill,
                        isOverview: showAllGroups
                    ))
                }

                // Sort largest first — larger clusters get label priority
                labels.sort { $0.area > $1.area }

                // Place labels, skipping any that overlap an already-placed label
                var placedRects: [CGRect] = []

                let viewBox = document.viewBox

                for label in labels {
                    let halfW = label.fontSize * 0.45
                    let halfH = label.fontSize * 0.55

                    // Clamp label center so pill stays within the SVG viewBox
                    let margin = label.fontSize * 0.65
                    let cx = min(max(label.center.x, viewBox.minX + margin), viewBox.maxX - margin)
                    let cy = min(max(label.center.y, viewBox.minY + margin), viewBox.maxY - margin)
                    let center = CGPoint(x: cx, y: cy)

                    let rect = CGRect(
                        x: center.x - halfW,
                        y: center.y - halfH,
                        width: halfW * 2,
                        height: halfH * 2
                    )

                    let overlaps = placedRects.contains { $0.intersects(rect) }
                    guard !overlaps else { continue }

                    placedRects.append(rect)

                    let pillOpacity: Double
                    let textWeight: Font.Weight
                    let textOpacity: Double
                    if label.isOverview {
                        pillOpacity = (label.needsPill ? 0.25 : 0.18) * label.alpha
                        textWeight = isLargeScreen ? .regular : .medium
                        textOpacity = 0.5 * label.alpha
                    } else {
                        pillOpacity = (label.needsPill ? 0.65 : 0.5) * label.alpha
                        textWeight = isLargeScreen ? .medium : .semibold
                        textOpacity = label.alpha
                    }
                    let pillW = label.fontSize * 1.1
                    let pillH = label.fontSize * 1.3
                    let pillRect = CGRect(
                        x: center.x - pillW / 2,
                        y: center.y - pillH / 2,
                        width: pillW,
                        height: pillH
                    )
                    let pill = Path(roundedRect: pillRect,
                                    cornerRadius: label.fontSize * 0.3)
                    ctx.fill(pill, with: .color(.black.opacity(pillOpacity)))

                    var text = AttributedString("\(label.groupNumber)")
                    text.font = .system(size: label.fontSize, weight: textWeight, design: .rounded)
                    text.foregroundColor = .white.opacity(textOpacity)

                    ctx.draw(Text(text), at: center, anchor: .center)
                }
            }
        }
    }

    // MARK: - Color Helpers (cached to avoid UIColor HSB conversion every frame)

    private static var mutedCache: [Int: Color] = [:]

    private static func cacheKey(_ color: Color, mode: UInt8) -> Int {
        color.hashValue &+ Int(mode) &* 31
    }

    private static func computeMuted(_ color: Color, selected: Bool) -> Color {
        let key = cacheKey(color, mode: selected ? 1 : 0)
        if let cached = mutedCache[key] { return cached }

        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        let baseBrightness = max(b, 0.35)
        let result: Color

        if selected {
            result = Color(hue: Double(h),
                         saturation: Double(s * 0.55),
                         brightness: Double(baseBrightness * 0.65))
        } else {
            result = Color(hue: Double(h),
                         saturation: Double(s * 0.06),
                         brightness: Double(baseBrightness * 0.15))
        }
        mutedCache[key] = result
        return result
    }

    /// Muted color for the "no color selected" overview state.
    /// Kept dim so the artwork emerges through coloring, not previewed upfront.
    private static func computeMutedOverview(_ color: Color) -> Color {
        let key = cacheKey(color, mode: 2)
        if let cached = mutedCache[key] { return cached }

        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let baseBrightness = max(b, 0.35)
        let result = Color(hue: Double(h),
                     saturation: Double(s * 0.10),
                     brightness: Double(baseBrightness * 0.22))
        mutedCache[key] = result
        return result
    }
}

// MARK: - DisplayLink Target

/// Bridging class for CADisplayLink since it requires an @objc target.
private final class DisplayLinkTarget: NSObject {
    let callback: () -> Void
    init(callback: @escaping () -> Void) { self.callback = callback }
    @objc func tick() { callback() }
}

// MARK: - Previews

#if DEBUG
#Preview("Canvas") {
    TodayView(store: ColoringStore(), coloringActive: .constant(true))
        .preferredColorScheme(.dark)
}
#endif
