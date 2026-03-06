import SwiftUI

/// The quiet ending. Appears over the dimmed, completed artwork.
/// No card, no button, no border — just words floating in stillness.
struct CompletionOverlayView: View {

    let message: String
    let count: Int
    var onDebugDismiss: (() -> Void)? = nil

    // Staged reveal
    @State private var showMessage = false
    @State private var showPostscript = false
    @State private var displayedCount: Int = 0
    @State private var initialAnimationDone = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Poetic message with animated count
            if showMessage {
                Text(formattedMessage)
                    .font(.system(size: 21, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 36)
                    .transition(.opacity.animation(.easeIn(duration: 0.8)))
                    .contentTransition(.numericText())
            }

            // Quiet postscript — arrives a beat later
            if showPostscript {
                Text("See you tomorrow.")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.4))
                    .transition(.opacity.animation(.easeIn(duration: 0.6)))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear { beginReveal() }
        .onChange(of: count) { _, newCount in
            if initialAnimationDone {
                withAnimation(.easeInOut(duration: 0.4)) {
                    displayedCount = newCount
                }
            }
        }
        // Long-press to dismiss (debug only — remove before shipping)
        .onLongPressGesture(minimumDuration: 1.5) {
            onDebugDismiss?()
        }
    }

    // MARK: - Staged Reveal

    private func beginReveal() {
        withAnimation(.easeIn(duration: 0.8)) {
            showMessage = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateCount()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.6)) {
                showPostscript = true
            }
        }
    }

    // MARK: - Count Animation

    private func animateCount() {
        let target = count
        guard target > 0 else {
            displayedCount = 0
            initialAnimationDone = true
            return
        }

        let totalDuration: Double = 1.8
        let steps = min(target, 60)
        let stepDuration = totalDuration / Double(steps)

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let eased = 1.0 - pow(1.0 - progress, 3)
            let value = Int(Double(target) * eased)

            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                displayedCount = value
                if step == steps {
                    initialAnimationDone = true
                }
            }
        }
    }

    // MARK: - Formatting

    private var formattedMessage: String {
        let countString = NumberFormatter.localizedString(
            from: NSNumber(value: displayedCount), number: .decimal
        )
        return message.replacingOccurrences(of: "[count]", with: countString)
    }
}

// MARK: - Previews

#Preview("Completion") {
    CompletionOverlayView(
        message: "Today, [count] people traced the oldest wish in the world back into color. It still means what it always meant.",
        count: 12_847
    )
    .background(.black)
    .preferredColorScheme(.dark)
}
