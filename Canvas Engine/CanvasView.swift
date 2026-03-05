import SwiftUI

struct CanvasView: View {
    @ObservedObject var store: DailyArtworkStore
    var onWrongColor: () -> Void = {}

    // Zoom + pan state
    @State private var currentZoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Fill interaction
    @State private var lastRegionID: Int? = nil
    @State private var pulse: FillPulse? = nil
    @State private var lastWrongTrigger: Date = .distantPast

    // Zoom limits
    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 6.0

    /// Numbers start appearing at this zoom level and are fully visible by numbersFullOpacity
    private let numbersAppearZoom: CGFloat = 1.8
    private let numbersFullZoom: CGFloat = 2.8

    var body: some View {
        GeometryReader { geo in
            let renderSize = renderedSize(in: geo.size)

            CanvasRenderer(
                artwork: store.artwork,
                filled: store.filledRegionIDs,
                pulse: pulse,
                numberOpacity: numberOpacity
            )
            .frame(width: renderSize.width, height: renderSize.height)
            .scaleEffect(currentZoom)
            .offset(offset)
            .contentShape(Rectangle())
            // Tap to fill
            .gesture(fillGesture(renderSize: renderSize))
            // Pinch to zoom
            .gesture(zoomGesture)
            // Pan
            .gesture(panGesture(renderSize: renderSize))
            // Double-tap to toggle zoom
            .onTapGesture(count: 2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if currentZoom > 1.5 {
                        currentZoom = 1.0
                        lastZoom = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        currentZoom = 3.0
                        lastZoom = 3.0
                    }
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .clipped()
    }

    // MARK: - Number Opacity

    private var numberOpacity: CGFloat {
        if currentZoom <= numbersAppearZoom { return 0 }
        if currentZoom >= numbersFullZoom { return 0.55 }
        let progress = (currentZoom - numbersAppearZoom) / (numbersFullZoom - numbersAppearZoom)
        return 0.55 * progress
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = lastZoom * value
                currentZoom = min(max(proposed, minZoom), maxZoom)
            }
            .onEnded { value in
                lastZoom = currentZoom
                clampOffset()
            }
    }

    private func panGesture(renderSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                clampOffset()
            }
    }

    private func fillGesture(renderSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Only allow filling when zoomed in enough to see numbers
                guard currentZoom >= numbersAppearZoom else { return }

                // Convert screen point to canvas coordinates
                let canvasPoint = screenToCanvas(value.location, renderSize: renderSize)

                guard let id = HitTest.regionID(
                    at: canvasPoint,
                    in: renderSize,
                    regions: store.artwork.regions,
                    tolerance: 8 / currentZoom  // Scale tolerance with zoom
                ) else { return }

                guard id != lastRegionID else { return }
                lastRegionID = id

                if store.tryFill(regionID: id) {
                    triggerPulse(regionID: id)
                } else {
                    throttleWrongColor()
                }
            }
            .onEnded { _ in
                lastRegionID = nil
            }
    }

    // MARK: - Coordinate Conversion

    /// Convert a screen-space touch point to canvas-space coordinates
    private func screenToCanvas(_ point: CGPoint, renderSize: CGSize) -> CGPoint {
        // The canvas is centered, scaled, and offset
        // Reverse: subtract offset, then divide by zoom, then account for centering
        let x = (point.x - offset.width) / currentZoom
        let y = (point.y - offset.height) / currentZoom
        return CGPoint(x: x, y: y)
    }

    // MARK: - Helpers

    private func renderedSize(in available: CGSize) -> CGSize {
        let aspect = store.artwork.aspectRatio
        let fitWidth = available.width
        let fitHeight = fitWidth / aspect

        if fitHeight <= available.height {
            return CGSize(width: fitWidth, height: fitHeight)
        } else {
            let h = available.height
            return CGSize(width: h * aspect, height: h)
        }
    }

    /// Keep the canvas from being panned off-screen
    private func clampOffset() {
        // Allow some overflow but not complete disappearance
        let maxX = max(0, (currentZoom - 1) * 200)
        let maxY = max(0, (currentZoom - 1) * 150)

        withAnimation(.easeOut(duration: 0.2)) {
            offset.width = min(max(offset.width, -maxX), maxX)
            offset.height = min(max(offset.height, -maxY), maxY)
            lastOffset = offset
        }
    }

    private func triggerPulse(regionID: Int) {
        pulse = FillPulse(regionID: regionID, trigger: UUID())
        DispatchQueue.main.asyncAfter(deadline: .now() + FillAnimation.duration) {
            if pulse?.regionID == regionID { pulse = nil }
        }
    }

    private func throttleWrongColor() {
        let now = Date()
        guard now.timeIntervalSince(lastWrongTrigger) > 0.25 else { return }
        lastWrongTrigger = now
        onWrongColor()
    }
}
