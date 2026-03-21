#if DEBUG
import SwiftUI

/// All-in-one debug panel — replaces scattered hidden gestures.
/// Double-tap gear icon in header to open.
struct TesterPanelView: View {
    @ObservedObject var store: ColoringStore
    /// Called when the panel wants to trigger a completion preview in TodayView.
    var onPreviewCompletion: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var jumpText: String = ""

    private let catalog = Artwork.catalog

    var body: some View {
        NavigationStack {
            List {
                navigationSection
                artworkInfoSection
                canvasDebugSection
                actionsSection
                togglesSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tester")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        Section("Navigation") {
            // Prev / index / Next row
            HStack {
                Button {
                    store.previousArtwork()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.bold)
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("\(store.currentArtworkIndex + 1) / \(catalog.count)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    store.nextArtwork()
                } label: {
                    Image(systemName: "chevron.right")
                        .fontWeight(.bold)
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.bordered)
            }

            // Jump to index
            HStack {
                TextField("Jump to #", text: $jumpText)
                    .keyboardType(.numberPad)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 120)

                Button("Go") {
                    if let num = Int(jumpText), num >= 1, num <= catalog.count {
                        store.loadArtwork(at: num - 1)
                        jumpText = ""
                    }
                }
                .buttonStyle(.bordered)
                .disabled(Int(jumpText).map { $0 >= 1 && $0 <= catalog.count } != true)

                Spacer()

                // Quick jumps
                Button("□ Square") { jumpToNext(square: true) }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .font(.caption)

                Button("▯ Portrait") { jumpToNext(square: false) }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                    .font(.caption)
            }
        }
    }

    // MARK: - Artwork Info

    private var artworkInfoSection: some View {
        Section("Artwork") {
            row("ID", store.currentArtwork.id)
            row("Name", store.currentArtwork.displayName)
            let vb = store.document.viewBox
            row("ViewBox", String(format: "%.0f, %.0f, %.0f, %.0f",
                                  vb.origin.x, vb.origin.y, vb.width, vb.height))
            row("Aspect", String(format: "%.3f", store.document.aspectRatio) +
                (store.document.aspectRatio > 0.99 && store.document.aspectRatio < 1.01 ? "  ■ SQUARE" : ""))
            row("Elements", "\(store.document.totalElements)")
            row("Groups", "\(store.document.groups.count)")
            row("Clusters", "\(store.document.clusters.count)")
            row("Filled", "\(store.filledElements.count) / \(store.document.totalElements)")
            row("Phase", store.phase == .painting ? "🎨 painting" : "✅ complete")
        }
    }

    // MARK: - Canvas Debug

    private var canvasDebugSection: some View {
        Section("Canvas") {
            let d = store.canvasDebug
            row("Viewport", sizeStr(d.viewportSize))
            row("RenderSize", sizeStr(d.renderSize))
            row("Zoom", String(format: "%.2f×", d.zoom))
            row("Offset", String(format: "(%.1f, %.1f)", d.offset.width, d.offset.height))
            row("Overflows", d.contentOverflows ? "YES ✓" : "no")
            if d.renderSize.width > 0 && d.viewportSize.width > 0 {
                let maxX = max(0, (d.renderSize.width * d.zoom - d.viewportSize.width) / 2)
                let maxY = max(0, (d.renderSize.height * d.zoom - d.viewportSize.height) / 2)
                row("Pan limit", String(format: "±%.0f × ±%.0f", maxX, maxY))
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Section("Actions") {
            Button("Reset Progress") {
                store.resetProgress()
            }
            .tint(.red)

            Button("Fill All (instant complete)") {
                store.fillAll()
            }
            .tint(.green)

            Button("Preview Completion") {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onPreviewCompletion()
                }
            }
            .tint(.blue)
        }
    }

    // MARK: - Toggles

    private var togglesSection: some View {
        Section("Toggles") {
            Toggle("Tiny Grab", isOn: Binding(
                get: { !store.debugDisableTinyGrab },
                set: { store.debugDisableTinyGrab = !$0 }
            ))
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
    }

    private func sizeStr(_ s: CGSize) -> String {
        String(format: "%.0f × %.0f", s.width, s.height)
    }

    private func jumpToNext(square: Bool) {
        let count = catalog.count
        for offset in 1..<count {
            let idx = (store.currentArtworkIndex + offset) % count
            let artwork = catalog[idx]
            if let doc = SVGDocumentCache.shared.peekDocument(for: artwork) {
                let isSquare = abs(doc.aspectRatio - 1.0) < 0.05
                if isSquare == square {
                    store.loadArtwork(at: idx)
                    return
                }
            }
        }
    }
}
#endif
