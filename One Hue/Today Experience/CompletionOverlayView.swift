import SwiftUI

/// The quiet ending. Appears over the dimmed, completed artwork.
/// No card, no button, no border — just words floating in stillness.
struct CompletionOverlayView: View {

    let message: String
    let count: Int

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
                    // Smoothly re-render when displayedCount changes from polling
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
        .onAppear { beginReveal() }
        .onChange(of: count) { _, newCount in
            // After initial animation, smoothly update from polling
            if initialAnimationDone {
                withAnimation(.easeInOut(duration: 0.4)) {
                    displayedCount = newCount
                }
            }
        }
    }

    // MARK: - Staged Reveal

    private func beginReveal() {
        // 1. Message fades in
        withAnimation(.easeIn(duration: 0.8)) {
            showMessage = true
        }

        // 2. Count rolls up over ~1.8s, starting after a short beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animateCount()
        }

        // 3. "See you tomorrow" arrives quietly, well after the message
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

        // Roll up in ~1.8 seconds with easing (fast start, slow finish)
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

#Preview("Completion — Short") {
    CompletionOverlayView(
        message: "[count] people sat here today. None of them were alone.",
        count: 3_291
    )
    .background(.black)
    .preferredColorScheme(.dark)
}
