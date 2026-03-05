import SwiftUI

struct CompletionOverlayView: View {
    let message: String
    let globalCountText: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(message)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(globalCountText)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.22))
                    .foregroundStyle(.white)
                    .padding(.top, 6)
            }
            .padding(26)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.black.opacity(0.40))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(24)
        }
        .transition(.opacity)
    }
}
