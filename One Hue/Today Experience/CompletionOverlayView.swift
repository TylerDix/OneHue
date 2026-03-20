import SwiftUI
import Combine

/// The quiet ending. Appears over the dimmed, completed artwork.
/// This is the app's resting state until midnight — nothing to tap,
/// nothing to dismiss. Just the message and a countdown.
struct CompletionOverlayView: View {

    let message: String
    let artworkID: String
    @ObservedObject var completionService: CompletionService
    var onNext: (() -> Void)? = nil
    var onGallery: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var isTodayArtwork: Bool = false
    /// Skip the staged reveal and show everything immediately (e.g. cold launch
    /// with an already-completed artwork).
    var skipReveal: Bool = false

    // Staged reveal — gentle cascade top → bottom
    @State private var showMessage = false
    @State private var showCount = false
    @State private var showCountdown = false
    @State private var showFeedback = false
    @State private var showNextButton = false

    // Feedback state
    /// Toggle for testing: true = 5-star rating, false = thumbs up/down (production)
    private static let useStarRating = true
    @State private var feedbackSubmitted = false
    @State private var starRating: Int = 0
    @State private var starComment: String = ""

    // Live countdown
    @State private var countdownText = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var alreadyRated: Bool {
        UserDefaults.standard.integer(forKey: "onehue.rated.\(artworkID)") > 0
    }

    // MARK: - Transition

    /// Unified fade-and-rise: every element enters the same way — gentle,
    /// cohesive, no visual competition between different motion types.
    private static let fadeRise: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .offset(y: 14)),
        removal: .opacity
    )

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Quote card
            if showMessage {
                VStack(spacing: 14) {
                    Text(Self.preventOrphan(message))
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .kerning(-0.2)

                    if showCount, isTodayArtwork, let count = completionService.globalCount, count > 0 {
                        Text(countText(count))
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .transition(.opacity.animation(.easeOut(duration: 0.8)))

                        if let flags = completionService.countryFlags, !flags.isEmpty {
                            Text(flags.joined(separator: " "))
                                .font(.system(size: 16))
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .transition(.opacity.animation(.easeOut(duration: 0.8)))
                        }
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
                .transition(Self.fadeRise)
            }

            // Countdown pill
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
                    .transition(Self.fadeRise)
            }

            // Inline feedback
            if showFeedback && !alreadyRated && !feedbackSubmitted {
                if Self.useStarRating {
                    // Star rating (testing)
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        starRating = star
                                    }
                                } label: {
                                    Image(systemName: star <= starRating ? "star.fill" : "star")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.white.opacity(star <= starRating ? 0.9 : 0.3))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if starRating > 0 {
                            TextField("Any thoughts?", text: $starComment)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(.white.opacity(0.08))
                                )
                                .frame(maxWidth: 280)
                                .transition(.opacity.combined(with: .offset(y: 6)))

                            Button {
                                submitRating(starRating, comment: starComment)
                            } label: {
                                Text("Submit")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(.white.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity)
                        }
                    }
                    .transition(Self.fadeRise)
                } else {
                    // Thumbs up/down (production)
                    HStack(spacing: 20) {
                        Button { submitRating(5) } label: {
                            Image(systemName: "hand.thumbsup")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(10)
                                .background(Circle().fill(.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Like this artwork")

                        Button { submitRating(1) } label: {
                            Image(systemName: "hand.thumbsdown")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(10)
                                .background(Circle().fill(.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dislike this artwork")
                    }
                    .transition(Self.fadeRise)
                }
            }

            if feedbackSubmitted {
                Text("Thanks!")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .transition(Self.fadeRise)
            }

            // Action buttons
            if showNextButton {
                HStack(spacing: 12) {
                    if let onShare {
                        Button(action: onShare) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Share")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    }

                    if isTodayArtwork, let onGallery {
                        Button(action: onGallery) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Gallery")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    } else if let onNext {
                        Button(action: onNext) {
                            HStack(spacing: 6) {
                                Text("Next")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(Self.fadeRise)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.25), location: 0),
                    .init(color: .black.opacity(0.55), location: 0.45),
                    .init(color: .black.opacity(0.80), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            updateCountdown()
            beginReveal()
            if isTodayArtwork {
                Task { await completionService.fetchCountryFlags(artworkID: artworkID) }
            }
        }
        .onReceive(timer) { _ in
            updateCountdown()
        }
    }

    // MARK: - Staged Reveal

    /// Gentle cascade: elements arrive top → bottom with the same easeOut curve.
    /// Total ~2.6s — still meditative but doesn't keep user waiting.
    private func beginReveal() {
        if skipReveal {
            showMessage = true
            showCount = true
            showCountdown = true
            showFeedback = true
            showNextButton = true
            return
        }

        // 0.0s — Quote card fades up
        withAnimation(.easeOut(duration: 0.8)) {
            showMessage = true
        }

        // 0.6s — Global count fades in beneath the quote
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.6)) {
                showCount = true
            }
        }

        // 1.3s — Countdown pill
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.6)) {
                showCountdown = true
            }
        }

        // 1.9s — Feedback buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeOut(duration: 0.5)) {
                showFeedback = true
            }
        }

        // 2.4s — Action buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeOut(duration: 0.5)) {
                showNextButton = true
            }
        }
    }

    // MARK: - Actions

    private func submitRating(_ value: Int, comment: String = "") {
        UserDefaults.standard.set(value, forKey: "onehue.rated.\(artworkID)")
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            feedbackSubmitted = true
        }

        Task {
            await CompletionService.shared.submitFeedback(
                artworkID: artworkID,
                rating: value,
                comment: comment
            )
        }
    }

    // MARK: - Helpers

    private func countText(_ count: Int) -> String {
        if count == 1 {
            return "You're the first today."
        } else {
            let formatted = count.formatted(.number)
            return "Colored by \(formatted) people today."
        }
    }

    /// Replaces the last space with a non-breaking space so the final
    /// two words always wrap together — no orphan words on the last line.
    static func preventOrphan(_ text: String) -> String {
        guard let range = text.range(of: " ", options: .backwards) else { return text }
        var result = text
        result.replaceSubrange(range, with: "\u{00A0}")
        return result
    }

    private func updateCountdown() {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
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

#Preview("Completion — Short") {
    CompletionOverlayView(
        message: "The horizon waits for no one.",
        artworkID: "preview",
        completionService: CompletionService.shared,
        onGallery: {},
        isTodayArtwork: true
    )
    .background(.black)
    .preferredColorScheme(.dark)
}

#Preview("Completion — Long Quote") {
    CompletionOverlayView(
        message: "The glass holds summer hostage while winter presses its face against the pane.",
        artworkID: "preview2",
        completionService: CompletionService.shared,
        onNext: {}
    )
    .background(.black)
    .preferredColorScheme(.dark)
}
