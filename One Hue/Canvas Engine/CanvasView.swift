import SwiftUI

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
    @State private var showNumbers: Bool = false
    @State private var showHint: Bool = true

    // Fill flash animation
    @State private var flashElements: [Int: Date] = [:]
    @State private var flashTick: UInt = 0

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
                    flashElements: flashElements,
                    flashTick: flashTick
                )
                .frame(width: renderSize.width, height: renderSize.height)

                // Tap to begin hint
                if showHint {
                    Text("Tap to begin")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .transition(.opacity)
                }
            }
            .frame(width: renderSize.width, height: renderSize.height)
            .scaleEffect(currentZoom)
            .offset(offset)
            .contentShape(Rectangle())
            .gesture(paintGesture(renderSize: renderSize))
            .simultaneousGesture(zoomGesture)
            .simultaneousGesture(panGesture)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .overlay {
                if let pos = cursorPosition, isLocked {
                    let originX = (geo.size.width - renderSize.width) / 2
                    let originY = (geo.size.height - renderSize.height) / 2
                    Circle()
                        .stroke(.white.opacity(0.7), lineWidth: 1.5)
                        .frame(width: cursorSize, height: cursorSize)
                        .position(x: originX + pos.x, y: originY + pos.y)
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
        .onChange(of: store.filledElements) { oldValue, newValue in
            let added = newValue.subtracting(oldValue)
            guard !added.isEmpty else { return }
            let now = Date()
            for idx in added { flashElements[idx] = now }
            // Drive ~30fps re-renders for the flash fade-out
            for frame in 1...12 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(frame) / 30.0) {
                    flashTick &+= 1
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                for idx in added { flashElements.removeValue(forKey: idx) }
            }
        }
        .onAppear { animate(to: store.phase) }
    }

    // MARK: - Phase Animation

    private func animate(to phase: ArtworkPhase) {
        switch phase {
        case .pristine:
            withAnimation(.easeInOut(duration: 0.5)) {
                showNumbers = false
                showHint = true
            }
            resetZoom()
            isLocked = false

        case .painting:
            withAnimation(.easeOut(duration: 0.2)) { showHint = false }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                showNumbers = true
            }

        case .complete:
            withAnimation(.easeOut(duration: 1.0)) { showNumbers = false }
            isLocked = false
        }
    }

    // MARK: - Paint Gesture

    private func paintGesture(renderSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let loc = value.location
                guard store.phase == .painting else { return }

                cursorPosition = loc

                // While locked: paint freely
                if isLocked {
                    if let elementIdx = screenToElement(loc, renderSize: renderSize) {
                        store.tryFill(elementIndex: elementIdx)
                    }
                    return
                }

                // First touch: decide paint or pan
                guard let elementIdx = screenToElement(loc, renderSize: renderSize) else {
                    panIfNeeded(value: value)
                    return
                }

                let groupIdx = store.document.elementGroupMap[elementIdx] ?? -1
                let isCorrect = groupIdx == store.selectedGroupIndex
                let needsFill = !store.filledElements.contains(elementIdx)

                if isCorrect && needsFill {
                    isLocked = true
                    store.tryFill(elementIndex: elementIdx)
                } else {
                    let dist = hypot(value.translation.width, value.translation.height)
                    if dist > 6 { panIfNeeded(value: value) }
                }
            }
            .onEnded { value in
                if store.phase == .pristine {
                    if hypot(value.translation.width, value.translation.height) < 10 {
                        store.beginPainting()
                    }
                    return
                }
                guard store.phase == .painting else { return }
                isLocked = false
                cursorPosition = nil
                lastOffset = offset
                clampOffset()
            }
    }

    // MARK: - Hit Testing

    private func screenToElement(_ point: CGPoint, renderSize: CGSize) -> Int? {
        // Transform screen point → SVG coordinate space
        let cx = renderSize.width / 2
        let cy = renderSize.height / 2
        let dx = (point.x - cx - offset.width) / currentZoom
        let dy = (point.y - cy - offset.height) / currentZoom
        let canvasX = dx + renderSize.width / 2
        let canvasY = dy + renderSize.height / 2

        let vb = store.document.viewBox
        let scale = min(renderSize.width / vb.width, renderSize.height / vb.height)
        let svgOffsetX = (renderSize.width - vb.width * scale) / 2
        let svgOffsetY = (renderSize.height - vb.height * scale) / 2

        let svgX = (canvasX - svgOffsetX) / scale
        let svgY = (canvasY - svgOffsetY) / scale
        let svgPoint = CGPoint(x: svgX, y: svgY)

        // Use spatial hash for candidate elements
        let candidates = store.spatialHash.candidates(at: svgPoint)

        // Test in reverse order (topmost element in SVG = last in parse order)
        for idx in candidates.reversed() {
            let element = store.document.elements[idx]
            guard element.bounds.contains(svgPoint) else { continue }
            if element.path.contains(svgPoint) {
                return idx
            }
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

    private func resetZoom(to zoom: CGFloat = 1.0) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentZoom = zoom; lastZoom = zoom
            offset = .zero; lastOffset = .zero
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
    let flashElements: [Int: Date]
    let flashTick: UInt  // drives re-renders during flash animation

    /// Minimum on-screen points a label must be to appear
    private let minScreenPt: CGFloat = 9
    /// How long the white flash lasts (seconds)
    private static let flashDuration: TimeInterval = 0.35

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
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.09))
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

            // Pass 1: Fill all elements
            for element in document.elements {
                let isFilled = filledElements.contains(element.id)
                guard let groupIdx = document.elementGroupMap[element.id] else { continue }
                let group = document.groups[groupIdx]
                let path = Path(element.path)

                if isFilled {
                    ctx.fill(path, with: .color(group.color))

                    // Animated flash overlay (fades white → transparent)
                    if let fillTime = flashElements[element.id] {
                        let elapsed = now.timeIntervalSince(fillTime)
                        if elapsed < Self.flashDuration {
                            let t = elapsed / Self.flashDuration
                            let alpha = (1.0 - t * t) * 0.55  // ease-out curve
                            ctx.fill(path, with: .color(.white.opacity(alpha)))
                        }
                    }
                } else {
                    let isSelected = groupIdx == selectedGroupIndex
                    ctx.fill(path, with: .color(mutedColor(group.color, selected: isSelected)))
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
            if showNumbers {
                let minVisible: CGFloat = 5
                let fullVisible: CGFloat = 14

                for cluster in document.clusters {
                    let hasUnfilled = cluster.elementIndices.contains { !filledElements.contains($0) }
                    guard hasUnfilled else { continue }

                    let dim = min(cluster.bounds.width, cluster.bounds.height)
                    let fontSize = max(min(dim * 0.35, 60), 4)
                    let screenPt = fontSize * scale * zoomLevel
                    guard screenPt >= minVisible else { continue }

                    let sizeAlpha = min((screenPt - minVisible) / (fullVisible - minVisible), 1.0)
                    let group = document.groups[cluster.groupIndex]
                    let isSelected = cluster.groupIndex == selectedGroupIndex
                    let baseAlpha: Double = isSelected ? 0.9 : 0.45

                    var text = AttributedString("\(group.id + 1)")
                    text.font = .system(size: fontSize, weight: .semibold, design: .rounded)
                    text.foregroundColor = .white.opacity(baseAlpha * sizeAlpha)

                    ctx.draw(Text(text), at: cluster.labelCenter, anchor: .center)
                }
            }
        }
    }

    // MARK: - Color Helpers

    private func mutedColor(_ color: Color, selected: Bool) -> Color {
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
#Preview("Pristine") {
    TodayView()
        .preferredColorScheme(.dark)
}
#endif
