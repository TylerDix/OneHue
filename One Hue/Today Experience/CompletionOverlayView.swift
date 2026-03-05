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
        guard count > 0 else {
            displayedCount = count
            return
        }

        // Roll up in ~1.8 seconds with easing (fast start, slow finish)
        let totalDuration: Double = 1.8
        let steps = min(count, 60)  // cap frame count for smoothness
        let stepDuration = totalDuration / Double(steps)

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            // Ease-out curve: fast at start, decelerates
            let eased = 1.0 - pow(1.0 - progress, 3)
            let value = Int(Double(count) * eased)

            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                displayedCount = value
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
