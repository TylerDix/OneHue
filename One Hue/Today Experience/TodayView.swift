import SwiftUI

struct TodayView: View {
    @ObservedObject var store: DailyArtworkStore

    @State private var showSettings = false
    @State private var showCompletion = false
    @State private var wrongColorToast = false

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                header

                CanvasView(store: store) {
                    showWrongColorToast()
                }
                .padding(.horizontal, 18)

                palette

                Spacer(minLength: 10)
            }
            .padding(.top, 14)
            .onChange(of: store.isComplete) { _, complete in
                if complete {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showCompletion = true
                    }
                }
            }

            if wrongColorToast && !showCompletion {
                Text("Not that one")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.55))
                            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                    )
                    .transition(.opacity)
                    .padding(.top, 56)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            if showCompletion {
                CompletionOverlayView(
                    message: store.artwork.completionMessage,
                    globalCountText: mockGlobalCountText(),
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showCompletion = false
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }

    private var header: some View {
        HStack {
            Text(store.artwork.title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Spacer()

            Text(store.progressText)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.10)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
    }

    private var palette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(store.artwork.palette.enumerated()), id: \.offset) { idx, c in
                    Button {
                        store.selectedColorIndex = idx
                    } label: {
                        Circle()
                            .fill(c)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle().stroke(.white.opacity(store.selectedColorIndex == idx ? 0.9 : 0.2),
                                               lineWidth: store.selectedColorIndex == idx ? 2 : 1)
                            )
                            .shadow(radius: store.selectedColorIndex == idx ? 8 : 0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
        }
    }

    private func showWrongColorToast() {
        guard !wrongColorToast else { return }
        withAnimation(.easeOut(duration: 0.12)) { wrongColorToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 0.2)) { wrongColorToast = false }
        }
    }

    private func mockGlobalCountText() -> String {
        let base = 3200
        let extra = store.artwork.id.hashValue.magnitude % 4200
        return "\(base + Int(extra)) people completed today"
    }
}
