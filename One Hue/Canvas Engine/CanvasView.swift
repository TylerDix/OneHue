import SwiftUI

struct CanvasView: View {
    @ObservedObject var store: DailyArtworkStore
    var onWrongColor: () -> Void = {}

    @State private var lastRegionID: Int? = nil
    @State private var pulse: FillPulse? = nil
    @State private var lastWrongTrigger: Date = .distantPast

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let renderSize = CGSize(width: side, height: side)

            CanvasRenderer(
                artwork: store.artwork,
                filled: store.filledRegionIDs,
                pulse: pulse
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let point = value.location

                        guard let id = HitTest.regionID(
                            at: point,
                            in: renderSize,
                            regions: store.artwork.regions,
                            tolerance: 8
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
            )
        }
    }

    private func triggerPulse(regionID: Int) {
        pulse = FillPulse(regionID: regionID, trigger: UUID())
        // Pulse retained briefly for future haptic/sound hooks
        DispatchQueue.main.asyncAfter(deadline: .now() + FillAnimation.duration) {
            if pulse?.regionID == regionID { pulse = nil }
        }
    }

    /// Prevents "Not that one" from firing 30 times per second during a drag.
    private func throttleWrongColor() {
        let now = Date()
        guard now.timeIntervalSince(lastWrongTrigger) > 0.25 else { return }
        lastWrongTrigger = now
        onWrongColor()
    }
}
