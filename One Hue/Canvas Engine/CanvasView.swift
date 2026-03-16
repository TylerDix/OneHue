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

    // Phase animation
    @State private var showNumbers: Bool = true

    // Blob fill animation
    @State private var activeAnimations: [FillAnimation] = []
    @State private var flashTick: UInt = 0
    @State private var blobOrigin: CGPoint? = nil
    @State private var animationLink: CADisplayLink?
    @State private var animationTarget: DisplayLinkTarget?

    // Pulse guide — breathing glow on largest unfilled cluster
    @State private var pulsePhase: Double = 0
    @State private var pulseTimer: Timer?

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 8.0
    private static let isIPad = UIDevice.current.userInterfaceIdiom == .pad
    /// iPad starts slightly zoomed so artwork fills the large screen and requires panning.
    private var defaultZoom: CGFloat { Self.isIPad ? 1.5 : 1.0 }

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
                    zoomLevel: currentZoom,
                    activeAnimations: activeAnimations,
                    flashTick: flashTick,
                    pulsePhase: pulsePhase
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
                // iPad starts zoomed so artwork fills the large screen
                if Self.isIPad {
                    currentZoom = defaultZoom; lastZoom = defaultZoom
                }
            }
            .onChange(of: geo.size) { _, newSize in
                viewportSize = newSize
                currentRenderSize = renderedSize(in: newSize)
            }
        }
        .clipped()
        .onChange(of: store.phase) { _, phase in animate(to: phase) }
        .onChange(of: store.completionDriftToken) { _, token in
            guard token > 0 else { return }
            slowDriftToCenter()
        }
        .onChange(of: store.findTargetToken) { _, token in
            guard token > 0 else { return }
            zoomToRect(store.findTargetBounds)
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
    }

    // MARK: - Phase Animation

    private func animate(to phase: ArtworkPhase) {
        switch phase {
        case .painting:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                showNumbers = true
                currentZoom = defaultZoom; lastZoom = defaultZoom
                offset = .zero; lastOffset = .zero
            }

        case .complete:
            withAnimation(.easeOut(duration: 1.0)) { showNumbers = false }
        }
    }

    // MARK: - Paint Gesture

    /// Tap-or-pan: fills happen on finger-lift only if the finger didn't travel far.
    /// This prevents accidental fills when the user intends to drag/pan.
    /// Set true once we schedule a fill; reset on onEnded.
    @State private var didFillThisGesture: Bool = false
    /// Set true when finger has moved enough to be a pan, cancelling any pending fill.
    @State private var gestureIsPan: Bool = false

    /// Points of travel before we consider it a pan and cancel the pending fill.
    private static let panThreshold: CGFloat = 6

    private func paintGesture(viewportSize: CGSize, renderSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Track movement — if the finger travels far, it's a pan
                let dist = hypot(value.translation.width, value.translation.height)
                if dist > Self.panThreshold {
                    gestureIsPan = true
                    if contentOverflows {
                        // Allow panning the canvas
                        offset = CGSize(
                            width:  lastOffset.width  + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                }

                guard store.phase == .painting, !store.isPeeking else { return }
                guard !isZooming else { return }
                guard !didFillThisGesture else { return }
                didFillThisGesture = true

                // Schedule fill after a tiny delay — if the finger moves or
                // a pinch starts before it fires, the fill is cancelled.
                let loc = value.location
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                    guard !isZooming, !gestureIsPan else { return }
                    attemptFill(at: loc, viewportSize: viewportSize, renderSize: renderSize)
                }
            }
            .onEnded { _ in
                didFillThisGesture = false
                gestureIsPan = false
                lastOffset = offset; clampOffset()
            }
    }

    private func attemptFill(at loc: CGPoint, viewportSize: CGSize, renderSize: CGSize) {
        guard let selected = store.selectedGroupIndex else { return }

        // Try exact hit
        if let hit = screenToElement(loc, viewportSize: viewportSize, renderSize: renderSize) {
            let groupIdx = store.document.elementGroupMap[hit.elementIndex] ?? -1
            let isCorrect = groupIdx == selected
            let needsFill = !store.filledElements.contains(hit.elementIndex)

            if isCorrect && needsFill {
                blobOrigin = hit.svgPoint
                store.tryFill(elementIndex: hit.elementIndex)
                return
            }
        }

        // Exact hit missed or wrong color — try color snap
        let svg = screenToSVGPoint(loc, viewportSize: viewportSize, renderSize: renderSize)
        if let snapIdx = colorSnapHit(svgPoint: svg, selectedGroup: selected) {
            blobOrigin = svg
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
                }
                let newZoom = min(max(lastZoom * value, minZoom), maxZoom)
                if currentZoom > 0.01 {
                    let scale = newZoom / currentZoom
                    offset = CGSize(
                        width:  offset.width  * scale,
                        height: offset.height * scale
                    )
                }
                currentZoom = newZoom
            }
            .onEnded { _ in
                lastZoom = currentZoom
                lastOffset = offset
                clampOffset()
                // Brief delay before re-enabling fills to prevent accidental
                // fill from finger lift at the end of a pinch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isZooming = false
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard contentOverflows else { return }
                offset = CGSize(
                    width:  lastOffset.width  + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                clampOffset()
            }
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

    private func clampOffset() {
        let maxX = max(0, (currentRenderSize.width * currentZoom - viewportSize.width) / 2)
        let maxY = max(0, (currentRenderSize.height * currentZoom - viewportSize.height) / 2)
        withAnimation(.easeOut(duration: 0.2)) {
            offset.width  = min(max(offset.width,  -maxX), maxX)
            offset.height = min(max(offset.height, -maxY), maxY)
            lastOffset = offset
        }
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

    private func resetZoom(to zoom: CGFloat? = nil) {
        let z = zoom ?? defaultZoom
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

    private static let blobDuration: TimeInterval = 0.6

    // MARK: - Checkerboard Tile

    /// 24×24 px checkerboard image (12 SVG-unit cells — tight pattern that
    /// reads as texture without blending into light-colored regions)
    private static let checkerImage: Image = {
        let cell = 12
        let size = cell * 2
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Image(systemName: "checkerboard.rectangle") }
        ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
        ctx.fill(CGRect(x: 0, y: 0, width: cell, height: cell))
        ctx.fill(CGRect(x: cell, y: cell, width: cell, height: cell))
        guard let cgImage = ctx.makeImage() else { return Image(systemName: "checkerboard.rectangle") }
        return Image(decorative: cgImage, scale: 1)
    }()

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
            for group in document.groups {
                mutedSel[group.id] = Self.computeMuted(group.color, selected: true)
                mutedOther[group.id] = Self.computeMuted(group.color, selected: false)
            }

            // Pass 1: Fill all elements (with blob reveal for active animations)
            for element in document.elements {
                let isFilled = isPeeking || filledElements.contains(element.id)
                guard let groupIdx = document.elementGroupMap[element.id],
                      groupIdx < document.groups.count else {
                    // Ungrouped element (border sliver): render as white, no interaction
                    let path = Path(element.path)
                    ctx.fill(path, with: .color(.white))
                    continue
                }
                let group = document.groups[groupIdx]
                let path = Path(element.path)

                // Check if this element is part of an active blob animation
                let anim = activeAnimations.first { $0.elementIndices.contains(element.id) }

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
                        let muted = (isSelected ? mutedSel[groupIdx] : mutedOther[groupIdx]) ?? .gray
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
                    let muted = (isSelected ? mutedSel[groupIdx] : mutedOther[groupIdx]) ?? .gray
                    ctx.fill(path, with: .color(muted))
                    ctx.stroke(path, with: .color(muted), style: gapStroke)
                }
            }

            // Pass 1.5: Subtle boundary hairlines on unfilled regions.
            // Gives consistent visual structure regardless of art style.
            if !isPeeking {
                let hairlineWidth: CGFloat = 0.5
                let hairlineStyle = StrokeStyle(lineWidth: hairlineWidth, lineJoin: .round)
                for element in document.elements {
                    guard !filledElements.contains(element.id) else { continue }
                    guard document.elementGroupMap[element.id] != nil else { continue }
                    let path = Path(element.path)
                    let isSelected = document.elementGroupMap[element.id] == selectedGroupIndex
                    let opacity = isSelected ? 0.15 : 0.07
                    ctx.stroke(path, with: .color(.white.opacity(opacity)), style: hairlineStyle)
                }
            }

            // Pass 2: Checkerboard on selected group's unfilled elements
            if showNumbers, !isPeeking, let selIdx = selectedGroupIndex, selIdx < document.groups.count {
                let selectedGroup = document.groups[selIdx]
                var combinedPath = Path()
                for idx in selectedGroup.elementIndices {
                    guard !filledElements.contains(idx) else { continue }
                    combinedPath.addPath(Path(document.elements[idx].path))
                }

                if !combinedPath.isEmpty {
                    ctx.drawLayer { layerCtx in
                        layerCtx.clip(to: combinedPath)
                        layerCtx.fill(
                            Path(vb),
                            with: .tiledImage(Self.checkerImage)
                        )
                    }

                    // Thin outline on selected group paths
                    ctx.stroke(combinedPath,
                               with: .color(.white.opacity(0.15)),
                               lineWidth: 0.8 / scale)
                }
            }

            // Pass 2.5: Breathing pulse on ALL unfilled regions of the selected group.
            // Flashes every remaining piece so the user can spot stragglers at any zoom.
            if pulsePhase > 0, !isPeeking, let selIdx = selectedGroupIndex, selIdx < document.groups.count {
                let selectedGroup = document.groups[selIdx]

                // Breathing sine wave: 0→1→0 over ~1.5s, repeated
                let breath = sin(pulsePhase * .pi * 1.3)
                let alpha = max(breath, 0) * 0.55  // peak 55% — must pop even on light colors

                // Build combined path from ALL unfilled elements in the selected group
                var allUnfilledPath = Path()
                for idx in selectedGroup.elementIndices where !filledElements.contains(idx) {
                    allUnfilledPath.addPath(Path(document.elements[idx].path))
                }

                if !allUnfilledPath.isEmpty {
                    ctx.fill(allUnfilledPath, with: .color(selectedGroup.color.opacity(alpha)))
                }
            }

            // Pass 3: Number labels. When no color selected, show all groups
            // with relaxed zoom threshold so numbers are visible at 1x.
            if showNumbers, !isPeeking {
                let showAllGroups = selectedGroupIndex == nil
                let minVisible: CGFloat = showAllGroups ? 3 : 8
                let fullVisible: CGFloat = showAllGroups ? 6 : 14

                struct LabelInfo {
                    let center: CGPoint
                    let fontSize: CGFloat
                    let alpha: Double
                    let groupNumber: Int
                    let area: CGFloat
                    let needsPill: Bool
                }

                var labels: [LabelInfo] = []

                for cluster in document.clusters {
                    if let selIdx = selectedGroupIndex {
                        guard cluster.groupIndex == selIdx else { continue }
                    }
                    let hasUnfilled = cluster.elementIndices.contains { !filledElements.contains($0) }
                    guard hasUnfilled else { continue }

                    let groupNumber = cluster.groupIndex < document.groups.count
                        ? document.groups[cluster.groupIndex].id + 1
                        : cluster.groupIndex + 1

                    let dim = min(cluster.bounds.width, cluster.bounds.height)
                    let naturalSize = min(dim * 0.35, 60)
                    let fontSize = max(naturalSize, CGFloat(24))
                    let needsPill = naturalSize < 24

                    // Numbers require a bit of zoom to appear — you search the
                    // artwork by color/tint first, numbers confirm when close.
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
                        needsPill: needsPill
                    ))
                }

                // Sort largest first — larger clusters get label priority
                labels.sort { $0.area > $1.area }

                // Place labels, skipping any that overlap an already-placed label
                var placedRects: [CGRect] = []

                for label in labels {
                    let halfW = label.fontSize * 0.45
                    let halfH = label.fontSize * 0.55
                    let rect = CGRect(
                        x: label.center.x - halfW,
                        y: label.center.y - halfH,
                        width: halfW * 2,
                        height: halfH * 2
                    )

                    let overlaps = placedRects.contains { $0.intersects(rect) }
                    guard !overlaps else { continue }

                    placedRects.append(rect)

                    let pillOpacity = label.needsPill ? 0.65 : 0.5
                    let pillW = label.fontSize * 1.1
                    let pillH = label.fontSize * 1.3
                    let pillRect = CGRect(
                        x: label.center.x - pillW / 2,
                        y: label.center.y - pillH / 2,
                        width: pillW,
                        height: pillH
                    )
                    let pill = Path(roundedRect: pillRect,
                                    cornerRadius: label.fontSize * 0.3)
                    ctx.fill(pill, with: .color(.black.opacity(pillOpacity * label.alpha)))

                    var text = AttributedString("\(label.groupNumber)")
                    text.font = .system(size: label.fontSize, weight: .semibold, design: .rounded)
                    text.foregroundColor = .white.opacity(label.alpha)

                    ctx.draw(Text(text), at: label.center, anchor: .center)
                }
            }
        }
    }

    // MARK: - Color Helpers

    private static func computeMuted(_ color: Color, selected: Bool) -> Color {
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        let baseBrightness = max(b, 0.35)

        if selected {
            // Warm color whisper — clearly shows "this color goes here"
            return Color(hue: Double(h),
                         saturation: Double(s * 0.55),
                         brightness: Double(baseBrightness * 0.65))
        } else {
            // Nearly invisible — fades into the dark canvas
            return Color(hue: Double(h),
                         saturation: Double(s * 0.06),
                         brightness: Double(baseBrightness * 0.15))
        }
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
    TodayView()
        .preferredColorScheme(.dark)
}
#endif
