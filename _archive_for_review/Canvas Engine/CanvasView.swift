import SwiftUI

struct CanvasView: View {
    @ObservedObject var store: DailyArtworkStore
    var onWrongColor: () -> Void = {}

    // Zoom + pan
    @State private var currentZoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat    = 1.0
    @State private var offset: CGSize       = .zero
    @State private var lastOffset: CGSize   = .zero

    // Grid interaction
    @State private var lastFilledCell: GridCell? = nil

    // Phase-driven animation values
    @State private var imageOpacity: CGFloat = 0.0   // 0 during painting, 1 on complete
    @State private var gridOpacity: CGFloat  = 0.0   // 0 pristine, 1 painting, 0 complete
    @State private var showHint: Bool        = true

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 8.0

    var body: some View {
        GeometryReader { geo in
            let renderSize = renderedSize(in: geo.size)
            let cs = cellSize(renderSize: renderSize)

            ZStack {
                // ── Layer 1: Source image — hidden during painting, revealed on complete ──
                if let img = store.artwork.sourceImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: renderSize.width, height: renderSize.height)
                        .opacity(imageOpacity)
                        .allowsHitTesting(false)
                }

                // ── Layer 2: Grid — black bg with grey outlines, colors fill in ──
                GridRenderer(
                    artwork: store.artwork,
                    filledCells: store.filledCells,
                    cellSize: cs
                )
                .frame(width: renderSize.width, height: renderSize.height)
                .opacity(gridOpacity)
                .allowsHitTesting(false)

                // ── Layer 3: Tap to begin hint ──
                if showHint {
                    Text("Tap to begin")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .transition(.opacity)
                }
            }
            .frame(width: renderSize.width, height: renderSize.height)
            .scaleEffect(currentZoom)
            .offset(offset)
            .contentShape(Rectangle())
            .gesture(paintGesture(geo: geo, renderSize: renderSize))
            .simultaneousGesture(zoomGesture)
            .simultaneousGesture(panGesture(renderSize: renderSize))
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .clipped()
        .onChange(of: store.phase) { _, phase in
            animate(to: phase)
        }
        .onAppear {
            // Restore correct visual state if app reopened mid-session
            animate(to: store.phase)
        }
    }

    // MARK: - Phase Animation

    private func animate(to phase: ArtworkPhase) {
        switch phase {
        case .pristine:
            // Pure black, hint visible, no grid, no image
            withAnimation(.easeInOut(duration: 0.5)) {
                gridOpacity  = 0.0
                imageOpacity = 0.0
                showHint     = true
            }
            resetZoom()

        case .painting:
            // Grid pops in over black, hint disappears, image stays hidden
            withAnimation(.easeOut(duration: 0.2)) { showHint = false }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                gridOpacity  = 1.0
                imageOpacity = 0.0
            }

        case .complete:
            // Grid dissolves, full-quality image fades in as the reward
            withAnimation(.easeOut(duration: 1.0)) { gridOpacity = 0.0 }
            withAnimation(.easeIn(duration: 1.2).delay(0.3)) { imageOpacity = 1.0 }
        }
    }

    // MARK: - Gestures

    private func paintGesture(geo: GeometryProxy, renderSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard store.phase == .painting else { return }
                if let cell = screenToCell(value.location, geo: geo, renderSize: renderSize),
                   cell != lastFilledCell {
                    lastFilledCell = cell
                    if store.tryFill(col: cell.col, row: cell.row) == .wrongColor {
                        throttleWrongColor()
                    }
                }
            }
            .onEnded { value in
                lastFilledCell = nil
                if store.phase == .pristine {
                    let d = value.translation
                    if sqrt(d.width * d.width + d.height * d.height) < 10 {
                        store.beginPainting()
                    }
                }
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentZoom = min(max(lastZoom * value, minZoom), maxZoom)
            }
            .onEnded { _ in
                lastZoom = currentZoom
                clampOffset()
            }
    }

    private func panGesture(renderSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard currentZoom > 1.05 else { return }
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

    // MARK: - Coordinate Conversion

    private func screenToCell(
        _ point: CGPoint,
        geo: GeometryProxy,
        renderSize: CGSize
    ) -> GridCell? {
        let cx = geo.size.width  / 2
        let cy = geo.size.height / 2
        let dx = (point.x - cx - offset.width)  / currentZoom
        let dy = (point.y - cy - offset.height) / currentZoom
        let canvasX = dx + renderSize.width  / 2
        let canvasY = dy + renderSize.height / 2

        let cs = cellSize(renderSize: renderSize)
        let col = Int(canvasX / cs.width)
        let row = Int(canvasY / cs.height)

        guard col >= 0, col < store.artwork.cols,
              row >= 0, row < store.artwork.rows else { return nil }
        return GridCell(col: col, row: row)
    }

    // MARK: - Layout

    private func renderedSize(in available: CGSize) -> CGSize {
        let aspect = store.artwork.aspectRatio
        let w = available.width
        let h = w / aspect
        if h <= available.height { return CGSize(width: w, height: h) }
        return CGSize(width: available.height * aspect, height: available.height)
    }

    private func cellSize(renderSize: CGSize) -> CGSize {
        CGSize(
            width:  renderSize.width  / CGFloat(store.artwork.cols),
            height: renderSize.height / CGFloat(store.artwork.rows)
        )
    }

    private func clampOffset() {
        let maxX = max(0, (currentZoom - 1) * 300)
        let maxY = max(0, (currentZoom - 1) * 300)
        withAnimation(.easeOut(duration: 0.2)) {
            offset.width  = min(max(offset.width,  -maxX), maxX)
            offset.height = min(max(offset.height, -maxY), maxY)
            lastOffset = offset
        }
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentZoom = 1.0; lastZoom   = 1.0
            offset = .zero;    lastOffset = .zero
        }
    }

    @State private var lastWrongTrigger: Date = .distantPast

    private func throttleWrongColor() {
        let now = Date()
        guard now.timeIntervalSince(lastWrongTrigger) > 0.3 else { return }
        lastWrongTrigger = now
        onWrongColor()
    }
}

// MARK: - Supporting types

struct GridCell: Equatable, Hashable {
    let col: Int
    let row: Int
}

struct GridRenderer: View {
    let artwork: DailyArtwork
    let filledCells: [GridCell: Int]
    let cellSize: CGSize

    var body: some View {
        Canvas { context, _ in
            let cw = cellSize.width
            let ch = cellSize.height

            for row in 0..<artwork.rows {
                for col in 0..<artwork.cols {
                    let colorIdx = artwork.colorIndex(col: col, row: row)
                    if artwork.isNonInteractive(colorIdx) { continue }

                    let rect = CGRect(
                        x: CGFloat(col) * cw, y: CGFloat(row) * ch,
                        width: cw, height: ch
                    )
                    let cell = GridCell(col: col, row: row)

                    if let filledIdx = filledCells[cell] {
                        // Filled — solid color, no border
                        context.fill(Path(rect), with: .color(artwork.palette[filledIdx]))
                    } else {
                        // Unfilled — pure black cell, subtle grey border, dim number
                        context.fill(Path(rect), with: .color(.black))
                        context.stroke(Path(rect),
                                       with: .color(.white.opacity(0.15)),
                                       lineWidth: 0.5)
                        if cw > 9 {
                            var text = AttributedString("\(colorIdx + 1)")
                            text.font = .system(size: min(cw * 0.42, 10),
                                                weight: .regular, design: .rounded)
                            text.foregroundColor = .white.opacity(0.25)
                            context.draw(Text(text),
                                         at: CGPoint(x: rect.midX, y: rect.midY),
                                         anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Pristine — pure black") {
    CanvasView(store: DailyArtworkStore())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}

#Preview("Painting — dark grid") {
    let store = DailyArtworkStore()
    let _ = { store.beginPainting() }()
    return CanvasView(store: store)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}

#Preview("Complete — image revealed") {
    let store = DailyArtworkStore()
    let _ = { store.debugForceComplete() }()
    return CanvasView(store: store)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
}
#endif
