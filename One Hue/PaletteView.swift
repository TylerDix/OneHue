import SwiftUI

/// Floating glass palette for One Hue.
/// Frosted swatches overlay the bottom of the canvas, letting artwork show through.
/// Selected swatch lifts into the art with stronger color. Completed colors celebrate
/// with a checkmark, then shrink-fade away.
struct PaletteView: View {

    let groups: [SVGColorGroup]
    @Binding var selectedIndex: Int?
    let filledElements: Set<Int>
    let justCompletedGroupIndex: Int?

    @State private var hasAppeared = false

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
                .padding(.vertical, 8)
            }
            .onChange(of: selectedIndex) { _, newIdx in
                if let idx = newIdx {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
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
        let labelColor: Color = lum > 0.45
            ? .black.opacity(0.85)
            : .white.opacity(0.95)
        let ringColor = Self.lighterTint(hex: group.hexColor)

        // Color intensity: selected gets stronger color, unselected stays glassy
        let colorOpacity: Double = isSelected || justCompleted ? 0.65 : 0.35

        Button {
            if group.id == selectedIndex {
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
                // Glass base — frosted material shows artwork through
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)

                // Color overlay — intensity varies by selection state
                Circle()
                    .fill(group.color.opacity(colorOpacity))
                    .frame(width: size, height: size)

                // Subtle glass border
                Circle()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    .frame(width: size, height: size)

                // Progress ring
                Circle()
                    .trim(from: 0, to: justCompleted ? 1.0 : progress)
                    .stroke(
                        ringColor.opacity(isSelected || justCompleted ? 1.0 : 0.6),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: size + 5, height: size + 5)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: progress)
                    .animation(.easeOut(duration: 0.5), value: justCompleted)

                // Completion glow
                if justCompleted {
                    Circle()
                        .strokeBorder(ringColor.opacity(0.5), lineWidth: 2)
                        .frame(width: size + 14, height: size + 14)
                        .shadow(color: ringColor.opacity(0.6), radius: 8, x: 0, y: 0)
                        .transition(.opacity)
                }

                // Selection ring
                if isSelected && !justCompleted {
                    Circle()
                        .strokeBorder(ringColor, lineWidth: 2)
                        .frame(width: size + 14, height: size + 14)
                        .shadow(color: ringColor.opacity(0.5), radius: 6, x: 0, y: 0)
                }

                // Label: checkmark on completion, number otherwise
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
            // Selected swatch rises into the artwork
            .offset(y: isSelected && !justCompleted ? -10 : 0)
            .scaleEffect(justCompleted ? 1.15 : (isSelected ? 1.12 : 1.0))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: justCompleted)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
