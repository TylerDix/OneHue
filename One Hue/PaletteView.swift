import SwiftUI

/// Bottom-anchored color palette for One Hue.
/// Each swatch shows its group number and remaining element count.
/// Completed colors fall off the palette. Auto-scrolls to selection.
struct PaletteView: View {

    let groups: [SVGColorGroup]
    @Binding var selectedIndex: Int
    let filledElements: Set<Int>
    let isComplete: Bool

    @State private var hasAppeared = false

    var body: some View {
        if !isComplete {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: swatchSpacing) {
                        ForEach(groups) { group in
                            let remaining = remainingCount(for: group)
                            let total = group.elementIndices.count

                            if remaining > 0 {
                                swatchButton(
                                    group: group,
                                    remaining: remaining,
                                    total: total
                                )
                                .id(group.id)
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 10)
                                .animation(
                                    .easeOut(duration: 0.3).delay(Double(group.id) * 0.025),
                                    value: hasAppeared
                                )
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.4), value: completedGroupCount)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .onChange(of: selectedIndex) { _, newIdx in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Swatch

    @ViewBuilder
    private func swatchButton(group: SVGColorGroup, remaining: Int, total: Int) -> some View {
        let isSelected = group.id == selectedIndex
        let size: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 46 : 38

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIndex = group.id
            }
        } label: {
            ZStack {
                Circle()
                    .fill(group.color)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    )

                if isSelected {
                    Circle()
                        .strokeBorder(.white.opacity(0.9), lineWidth: 2.5)
                        .frame(width: size + 8, height: size + 8)
                }

                VStack(spacing: -1) {
                    Text("\(group.id + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)

                    if remaining < total {
                        Text("\(remaining)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
                    }
                }
            }
            .scaleEffect(isSelected ? 1.1 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Counts

    private func remainingCount(for group: SVGColorGroup) -> Int {
        let filled = group.elementIndices.filter { filledElements.contains($0) }.count
        return group.elementIndices.count - filled
    }

    private var completedGroupCount: Int {
        groups.filter { remainingCount(for: $0) == 0 }.count
    }

    private var swatchSpacing: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 12 : 10
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Palette") {
    let store = ColoringStore()
    return PaletteView(
        groups: store.document.groups,
        selectedIndex: .constant(0),
        filledElements: store.filledElements,
        isComplete: false
    )
    .padding()
    .background(Color.black)
}
#endif
