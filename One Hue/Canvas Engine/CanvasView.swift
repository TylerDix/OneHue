import SwiftUI

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

    // Paint-lock state
    @State private var isLocked: Bool = false
    @State private var cursorPosition: CGPoint? = nil

    // Phase animation
    @State private var showNumbers: Bool = true

    // Blob fill animation
    @State private var activeAnimations: [FillAnimation] = []
    @State private var flashTick: UInt = 0
    @State private var blobOrigin: CGPoint? = nil

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 8.0
    private let cursorSize: CGFloat = 48

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
                    zoomLevel: currentZoom,
                    activeAnimations: activeAnimations,
                    flashTick: flashTick
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
            .overlay {
                if let pos = cursorPosition, isLocked {
                    Circle()
                        .stroke(.white.opacity(0.7), lineWidth: 1.5)
                        .frame(width: cursorSize, height: cursorSize)
                        .position(x: pos.x, y: pos.y)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                viewportSize = geo.size
                currentRenderSize = renderSize
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
            guard !added.isEmpty, let origin = blobOrigin else { return }
            let maxRadius = blobMaxRadius(from: origin, elements: added)

            let animation = FillAnimation(
                origin: origin,
                startTime: Date(),
                maxRadius: maxRadius,
                elementIndices: added
            )
            activeAnimations.append(animation)

            // Drive ~60fps re-renders for smooth blob expansion
            let totalFrames = 36
            for frame in 1...totalFrames {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(frame) / 60.0) {
                    flashTick &+= 1
                }
            }

            // Remove animation after it completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                activeAnimations.removeAll { $0.startTime == animation.startTime }
            }

            blobOrigin = nil
        }
        .onAppear { animate(to: store.phase) }
    }

    // MARK: - Phase Animation

    private func animate(to phase: ArtworkPhase) {
        switch phase {
        case .painting:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                showNumbers = true
            }

        case .complete:
            withAnimation(.easeOut(duration: 1.0)) { showNumbers = false }
            isLocked = false
        }
    }

    // MARK: - Paint Gesture

    private func paintGesture(viewportSize: CGSize, renderSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let loc = value.location
                guard store.phase == .painting else { return }

                cursorPosition = loc

                // While locked: paint freely
                if isLocked {
                    if let hit = screenToElement(loc, viewportSize: viewportSize, renderSize: renderSize) {
                        blobOrigin = hit.svgPoint
                        store.tryFill(elementIndex: hit.elementIndex)
                    }
                    return
                }

                // First touch: decide paint or pan
                guard let hit = screenToElement(loc, viewportSize: viewportSize, renderSize: renderSize) else {
                    panIfNeeded(value: value)
                    return
                }

                let groupIdx = store.document.elementGroupMap[hit.elementIndex] ?? -1
                let isCorrect = groupIdx == store.selectedGroupIndex
                let needsFill = !store.filledElements.contains(hit.elementIndex)

                if isCorrect && needsFill {
                    isLocked = true
                    blobOrigin = hit.svgPoint
                    store.tryFill(elementIndex: hit.elementIndex)
                } else {
                    let dist = hypot(value.translation.width, value.translation.height)
                    if dist > 6 { panIfNeeded(value: value) }
                }
            }
            .onEnded { _ in
                guard store.phase == .painting else { return }
                isLocked = false
                cursorPosition = nil
                lastOffset = offset
                clampOffset()
            }
    }

    // MARK: - Hit Testing

    /// How far (in SVG units) to search for a nearby element when the
    /// exact tap misses. Scales with zoom so it feels consistent on screen.
    private static let tapMarginBase: CGFloat = 40

    private func screenToElement(_ point: CGPoint, viewportSize: CGSize, renderSize: CGSize) -> (elementIndex: Int, svgPoint: CGPoint)? {
        // Transform screen point (in viewport space) → SVG coordinate space
        // Content is centered in the viewport
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

        let svgX = (canvasX - svgOffsetX) / scale
        let svgY = (canvasY - svgOffsetY) / scale
        let svgPoint = CGPoint(x: svgX, y: svgY)

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

            // Hit radius based on label font size (same formula as renderer)
            let dim = min(cluster.bounds.width, cluster.bounds.height)
            let fontSize = max(min(dim * 0.35, 60), 8)
            let hitRadius = max(fontSize * 0.7, 20)

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
        let margin = Self.tapMarginBase / max(currentZoom, 0.5)
        let searchRect = CGRect(x: svgX - margin, y: svgY - margin,
                                width: margin * 2, height: margin * 2)

        var bestIdx: Int?
        var bestDist: CGFloat = .greatestFiniteMagnitude

        let expanded = store.spatialHash.candidates(in: searchRect)
        for idx in expanded {
            let b = store.document.elements[idx].bounds
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
        }

        if let idx = bestIdx, bestDist < margin * margin {
            return (idx, svgPoint)
        }
        return nil
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
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isLocked, contentOverflows else { return }
                offset = CGSize(
                    width:  lastOffset.width  + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard !isLocked else { return }
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

    private func resetZoom(to zoom: CGFloat = 1.0) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentZoom = zoom; lastZoom = zoom
            offset = .zero; lastOffset = .zero
        }
    }

    /// Slowly drifts back to center — called after the completion freeze.
    private func slowDriftToCenter() {
        cursorPosition = nil
        withAnimation(.easeInOut(duration: 1.5)) {
            currentZoom = 1.0; lastZoom = 1.0
            offset = .zero; lastOffset = .zero
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
        let canvasX = svgRect.midX * scale + svgOffsetX
        let canvasY = svgRect.midY * scale + svgOffsetY
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
    let selectedGroupIndex: Int
    let showNumbers: Bool
    let zoomLevel: CGFloat
    let activeAnimations: [FillAnimation]
    let flashTick: UInt  // drives re-renders during blob animation

    private static let blobDuration: TimeInterval = 0.6

    // MARK: - Checkerboard Tile

    /// 48×48 px checkerboard image (24 SVG-unit cells when drawn at scale 1)
    private static let checkerImage: Image = {
        let cell = 24
        let size = cell * 2
        let space = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
        ctx.fill(CGRect(x: 0, y: 0, width: cell, height: cell))
        ctx.fill(CGRect(x: cell, y: cell, width: cell, height: cell))
        return Image(decorative: ctx.makeImage()!, scale: 1)
    }()

    // MARK: - Body

    var body: some View {
        Canvas { context, size in
            let vb = document.viewBox
            let scaleX = size.width / vb.width
            let scaleY = size.height / vb.height
            let scale = min(scaleX, scaleY)

            let offsetX = (size.width - vb.width * scale) / 2
            let offsetY = (size.height - vb.height * scale) / 2

            var ctx = context
            ctx.translateBy(x: offsetX, y: offsetY)
            ctx.scaleBy(x: scale, y: scale)

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
                let isFilled = filledElements.contains(element.id)
                guard let groupIdx = document.elementGroupMap[element.id] else { continue }
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

            // Pass 2: Checkerboard on selected group's unfilled elements
            if showNumbers {
                let selectedGroup = document.groups[selectedGroupIndex]
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

            // Pass 3: Number labels — one per cluster, graduated opacity on zoom
            // Uses overlap detection to prevent stacking.
            if showNumbers {
                let minVisible: CGFloat = 5
                let fullVisible: CGFloat = 14

                // Non-selected labels fade out between 2× and 3.5× zoom
                let fadeStart: CGFloat = 2.0
                let fadeEnd: CGFloat = 3.5
                let otherGroupFade = 1.0 - min(max((zoomLevel - fadeStart) / (fadeEnd - fadeStart), 0), 1)

                // Collect labels sorted by cluster area (largest first → priority)
                struct LabelInfo {
                    let center: CGPoint
                    let fontSize: CGFloat
                    let alpha: Double
                    let groupNumber: Int
                    let area: CGFloat
                }

                var labels: [LabelInfo] = []

                for cluster in document.clusters {
                    let hasUnfilled = cluster.elementIndices.contains { !filledElements.contains($0) }
                    guard hasUnfilled else { continue }

                    let isSelected = cluster.groupIndex == selectedGroupIndex
                    guard isSelected || otherGroupFade > 0.01 else { continue }

                    let dim = min(cluster.bounds.width, cluster.bounds.height)
                    let fontSize = max(min(dim * 0.35, 60), 4)
                    let screenPt = fontSize * scale * zoomLevel
                    guard screenPt >= minVisible else { continue }

                    let sizeAlpha = min((screenPt - minVisible) / (fullVisible - minVisible), 1.0)
                    let baseAlpha: Double = isSelected ? 0.9 : 0.45 * otherGroupFade
                    let area = cluster.bounds.width * cluster.bounds.height

                    labels.append(LabelInfo(
                        center: cluster.labelCenter,
                        fontSize: fontSize,
                        alpha: baseAlpha * sizeAlpha,
                        groupNumber: document.groups[cluster.groupIndex].id + 1,
                        area: area
                    ))
                }

                // Sort largest first — larger clusters get label priority
                labels.sort { $0.area > $1.area }

                // Place labels, skipping any that overlap an already-placed label
                var placedRects: [CGRect] = []

                for label in labels {
                    // Approximate label bounds in SVG space
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
            return Color(hue: Double(h),
                         saturation: Double(s * 0.35),
                         brightness: Double(baseBrightness * 0.45))
        } else {
            return Color(hue: Double(h),
                         saturation: Double(s * 0.2),
                         brightness: Double(baseBrightness * 0.3))
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Canvas") {
    TodayView()
        .preferredColorScheme(.dark)
}
#endif
