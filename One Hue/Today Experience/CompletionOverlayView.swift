import SwiftUI

/// The quiet ending. Appears over the dimmed, completed artwork.
struct CompletionOverlayView: View {

    let message: String
    var onDismiss: (() -> Void)? = nil

    // Staged reveal
    @State private var showMessage = false
    @State private var showPostscript = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if showMessage {
                Text(message)
                    .font(.system(size: 21, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
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
        .onLongPressGesture(minimumDuration: 1.5) {
            onDismiss?()
        }
    }

    private func beginReveal() {
        withAnimation(.easeIn(duration: 0.8)) {
            showMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeIn(duration: 0.6)) {
                showPostscript = true
            }
        }
    }
}

#Preview("Completion") {
    CompletionOverlayView(message: "Every shape found its color.")
        .background(.black)
        .preferredColorScheme(.dark)
}
