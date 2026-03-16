import SwiftUI

/// Bottom-anchored color palette for One Hue.
/// Each swatch shows its group number with a radial progress ring.
/// Completed colors flash a checkmark then fall off. Auto-scrolls to selection.
struct PaletteView: View {

    let groups: [SVGColorGroup]
    @Binding var selectedIndex: Int?
    let filledElements: Set<Int>
    let justCompletedGroupIndex: Int?
    var onRetap: (() -> Void)? = nil

    @State private var hasAppeared = false

    /// Fixed palette height so canvas doesn't jump when swatches appear/disappear.
    private var paletteHeight: CGFloat {
        let size: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 58 : 54
        return size + 30  // swatch + ring + padding
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: swatchSpacing) {
                    ForEach(groups) { group in
                        let remaining = remainingCount(for: group)
                        let total = group.elementIndices.count
                        let justCompleted = group.id == justCompletedGroupIndex

                        if remaining > 0 || justCompleted {
                            swatchButton(
                                group: group,
                                remaining: remaining,
                                total: total,
                                justCompleted: justCompleted
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
                                removal: .scale(scale: 0.6)
                                    .combined(with: .opacity)
                            ))
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: completedGroupCount)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .onChange(of: selectedIndex) { _, newIdx in
                if let idx = newIdx {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
        .frame(height: paletteHeight)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Swatch

    @ViewBuilder
    private func swatchButton(
        group: SVGColorGroup,
        remaining: Int,
        total: Int,
        justCompleted: Bool
    ) -> some View {
        let isSelected = group.id == selectedIndex
        let size: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 58 : 54
        let progress = total > 0 ? Double(total - remaining) / Double(total) : 0
        let lum = Self.relativeLuminance(hex: group.hexColor)
        let isDark = lum < 0.08
        let labelColor: Color = lum > 0.45
            ? .black.opacity(0.7)
            : .white.opacity(0.95)
        let ringColor = Self.lighterTint(hex: group.hexColor)

        Button {
            if group.id == selectedIndex {
                // Deselect — shows all numbers so user can pick a different color
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedIndex = nil
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedIndex = group.id
                }
            }
        } label: {
            ZStack {
                // Background circle
                Circle()
                    .fill(group.color)
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isDark ? .white.opacity(0.3) : .white.opacity(0.12),
                                lineWidth: isDark ? 1.5 : 1
                            )
                    )

                // Progress ring — smooth arc to full on completion
                Circle()
                    .trim(from: 0, to: justCompleted ? 1.0 : progress)
                    .stroke(
                        ringColor.opacity(isSelected || justCompleted ? 1.0 : 0.7),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: size + 6, height: size + 6)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: progress)
                    .animation(.easeOut(duration: 0.5), value: justCompleted)

                // Completion glow ring — soft radiance on complete
                if justCompleted {
                    Circle()
                        .strokeBorder(ringColor.opacity(0.5), lineWidth: 2)
                        .frame(width: size + 16, height: size + 16)
                        .shadow(color: ringColor.opacity(0.6), radius: 8, x: 0, y: 0)
                        .transition(.opacity)
                }

                // Selection ring — color-matched
                if isSelected && !justCompleted {
                    Circle()
                        .strokeBorder(ringColor, lineWidth: 2.5)
                        .frame(width: size + 16, height: size + 16)
                        .shadow(color: ringColor.opacity(0.4), radius: 5, x: 0, y: 0)
                }

                // Completion checkmark replaces number with spring bounce
                if justCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(labelColor)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.5)),
                            removal: .opacity
                        ))
                } else {
                    // Group number
                    Text("\(group.id + 1)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(labelColor)
                        .shadow(
                            color: lum > 0.45
                                ? .white.opacity(0.3)
                                : .black.opacity(0.5),
                            radius: 1, x: 0, y: 1
                        )
                }
            }
            // Subtle lift for selected swatch — rises slightly without affecting neighbors
            .offset(y: isSelected && !justCompleted ? -6 : 0)
            .scaleEffect(justCompleted ? 1.15 : (isSelected ? 1.08 : 1.0))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: justCompleted)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(justCompleted)
        .accessibilityLabel("Color \(group.id + 1), \(remaining) of \(total) remaining")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Color Helpers

    /// Relative luminance (0 = black, 1 = white).
    private static func relativeLuminance(hex: String) -> Double {
        let (r, g, b) = rgb(from: hex)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// A lighter, more saturated tint of the hex color for rings.
    private static func lighterTint(hex: String) -> Color {
        let (r, g, b) = rgb(from: hex)
        // Convert to HSB, boost brightness and keep saturation punchy
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &br, alpha: &a)
        let newBrightness = min(br + 0.45, 1.0)
        let newSaturation = min(s * 1.1, 1.0)
        return Color(hue: Double(h), saturation: Double(newSaturation), brightness: Double(newBrightness))
    }

    /// Parse hex → (r, g, b) as Doubles 0–1.
    private static func rgb(from hex: String) -> (Double, Double, Double) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6,
              let val = UInt64(cleaned, radix: 16) else { return (0.5, 0.5, 0.5) }
        let r = Double((val >> 16) & 0xFF) / 255.0
        let g = Double((val >> 8) & 0xFF) / 255.0
        let b = Double(val & 0xFF) / 255.0
        return (r, g, b)
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
        UIDevice.current.userInterfaceIdiom == .pad ? 16 : 14
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Palette") {
    let store = ColoringStore()
    return PaletteView(
        groups: store.document.groups,
        selectedIndex: .constant(nil),
        filledElements: store.filledElements,
        justCompletedGroupIndex: nil
    )
    .padding()
    .background(Color.black)
}
#endif
