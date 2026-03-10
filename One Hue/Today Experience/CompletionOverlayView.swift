import SwiftUI
import Combine

/// The quiet ending. Appears over the dimmed, completed artwork.
/// This is the app's resting state until midnight — nothing to tap,
/// nothing to dismiss. Just the message and a countdown.
struct CompletionOverlayView: View {

    let message: String
    let artworkID: String
    @ObservedObject var completionService: CompletionService
    var onShare: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil

    // Staged reveal
    @State private var showMessage = false
    @State private var showCount = false
    @State private var showCountdown = false
    @State private var showShareButton = false
    @State private var showFeedback = false
    @State private var showNextButton = false

    // Feedback state
    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var feedbackSubmitted = false
    @State private var showCommentField = false

    // Live countdown
    @State private var countdownText = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var alreadyRated: Bool {
        UserDefaults.standard.integer(forKey: "onehue.rated.\(artworkID)") > 0
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if showMessage {
                VStack(spacing: 14) {
                    Text(message)
                        .font(.system(size: 21, weight: .light, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)

                    if showCount, let count = completionService.globalCount, count > 0 {
                        Text(countText(count))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .transition(.opacity.animation(.easeIn(duration: 0.8)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: 360)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.black.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .transition(.opacity.animation(.easeIn(duration: 0.8)))
            }

            if showCountdown {
                Text(countdownText)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.45))
                            .overlay(
                                Capsule()
                                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
                    .transition(.opacity.animation(.easeIn(duration: 0.6)))
            }

            // Inline feedback
            if showFeedback && !alreadyRated && !feedbackSubmitted {
                VStack(spacing: 14) {
                    // Star rating
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    rating = star
                                    showCommentField = true
                                }
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white.opacity(star <= rating ? 0.9 : 0.3))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Comment field (appears after rating)
                    if showCommentField {
                        TextField("Any thoughts?", text: $comment)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.white.opacity(0.06))
                            )
                            .frame(maxWidth: 280)
                            .transition(.opacity.animation(.easeIn(duration: 0.4)))

                        Button {
                            submitFeedback()
                        } label: {
                            Text("Submit")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(.white.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.animation(.easeIn(duration: 0.3)))
                    }
                }
                .transition(.opacity.animation(.easeIn(duration: 0.6)))
            }

            if feedbackSubmitted {
                Text("Thanks!")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .transition(.opacity.animation(.easeIn(duration: 0.5)))
            }

            // Action buttons
            HStack(spacing: 20) {
                if showShareButton, let onShare {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(10)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.animation(.easeIn(duration: 0.6)))
                }

                if showNextButton, let onNext {
                    Button(action: onNext) {
                        HStack(spacing: 6) {
                            Text("Next")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.animation(.easeIn(duration: 0.6)))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updateCountdown()
            beginReveal()
        }
        .onReceive(timer) { _ in
            updateCountdown()
        }
    }

    private func beginReveal() {
        withAnimation(.easeIn(duration: 0.8)) {
            showMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeIn(duration: 0.8)) {
                showCount = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeIn(duration: 0.6)) {
                showCountdown = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeIn(duration: 0.6)) {
                showShareButton = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            withAnimation(.easeIn(duration: 0.6)) {
                showFeedback = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation(.easeIn(duration: 0.6)) {
                showNextButton = true
            }
        }
    }

    private func submitFeedback() {
        guard rating > 0 else { return }
        UserDefaults.standard.set(rating, forKey: "onehue.rated.\(artworkID)")
        withAnimation { feedbackSubmitted = true }

        Task {
            await CompletionService.shared.submitFeedback(
                artworkID: artworkID,
                rating: rating,
                comment: comment
            )
        }
    }

    private func countText(_ count: Int) -> String {
        if count == 1 {
            return "You're the first today."
        } else {
            let formatted = count.formatted(.number)
            return "Colored by \(formatted) people today."
        }
    }

    private func updateCountdown() {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        guard let midnight = utcCal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else {
            countdownText = ""
            return
        }
        let diff = utcCal.dateComponents([.hour, .minute], from: now, to: midnight)
        let h = diff.hour ?? 0
        let m = diff.minute ?? 0
        countdownText = "New image in \(h)h \(m)m"
    }
}

#Preview("Completion") {
    CompletionOverlayView(
        message: "The horizon waits for no one.",
        artworkID: "preview",
        completionService: CompletionService.shared
    )
    .background(.black)
    .preferredColorScheme(.dark)
}
