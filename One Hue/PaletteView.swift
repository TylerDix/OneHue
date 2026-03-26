import SwiftUI

/// Bottom palette bar for One Hue.
/// Solid dark bar with round color swatches — selected swatch lifts with a ring.
/// Modeled after Happy Color / top coloring apps: clean, functional, no glass.
struct PaletteView: View {

    let groups: [SVGColorGroup]
    @Binding var selectedIndex: Int?
    let filledElements: Set<Int>
    let justCompletedGroupIndex: Int?

    @State private var hasAppeared = false

    private var swatchSize: CGFloat {
        isIPad ? 64 : 58
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
                            swatch(
                                group: group,
                                remaining: remaining,
                                total: total,
                                justCompleted: justCompleted
                            )
                            .id(group.id)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 8)
                            .animation(
                                .easeOut(duration: 0.3).delay(Double(group.id) * 0.025),
                                value: hasAppeared
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale(scale: 0.6).combined(with: .opacity)
                            ))
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: completedGroupCount)
                .padding(.horizontal, 20)
                // Push swatches down so lift/glow doesn't clip at top
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
            .scrollClipDisabled()
            .onChange(of: selectedIndex) { _, newIdx in
                if let idx = newIdx {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
        // Fixed height: swatch + top padding + bottom padding
        .frame(height: swatchSize + 36)
        .clipped()
        .background(Color.black)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Swatch

    @ViewBuilder
    private func swatch(
        group: SVGColorGroup,
        remaining: Int,
        total: Int,
        justCompleted: Bool
    ) -> some View {
        let isSelected = group.id == selectedIndex
        let progress = total > 0 ? Double(total - remaining) / Double(total) : 0
        let lum = Self.relativeLuminance(hex: group.hexColor)
        let labelColor: Color = lum > 0.45 ? .black.opacity(0.9) : .white
        let ringColor = Self.lighterTint(hex: group.hexColor)

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedIndex = group.id == selectedIndex ? nil : group.id
            }
        } label: {
            ZStack {
                // Color fill
                Circle()
                    .fill(group.color)
                    .frame(width: swatchSize, height: swatchSize)

                // Subtle inner shadow for depth
                Circle()
                    .strokeBorder(.black.opacity(0.15), lineWidth: 1)
                    .frame(width: swatchSize, height: swatchSize)

                // Progress track + fill ring (sits tight around swatch)
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 3.5)
                    .frame(width: swatchSize + 6, height: swatchSize + 6)

                // Selection glow disc + white ring (outside progress ring)
                if isSelected && !justCompleted {
                    Circle()
                        .fill(ringColor.opacity(0.35))
                        .frame(width: swatchSize + 26, height: swatchSize + 26)
                        .blur(radius: 6)
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                        .frame(width: swatchSize + 16, height: swatchSize + 16)
                }

                if progress > 0 || justCompleted {
                    Circle()
                        .trim(from: 0, to: justCompleted ? 1.0 : progress)
                        .stroke(
                            ringColor.opacity(isSelected || justCompleted ? 1.0 : 0.7),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: swatchSize + 6, height: swatchSize + 6)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.3), value: progress)
                        .animation(.easeOut(duration: 0.5), value: justCompleted)
                }

                // Completion glow
                if justCompleted {
                    Circle()
                        .strokeBorder(ringColor.opacity(0.6), lineWidth: 2)
                        .frame(width: swatchSize + 12, height: swatchSize + 12)
                        .shadow(color: ringColor.opacity(0.5), radius: 6)
                        .transition(.opacity)
                }

                // Label
                if justCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(labelColor)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.3).combined(with: .opacity)
                                .animation(.spring(response: 0.4, dampingFraction: 0.5)),
                            removal: .opacity
                        ))
                } else {
                    Text("\(group.id + 1)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(labelColor)
                        .shadow(
                            color: lum > 0.45 ? .white.opacity(0.2) : .black.opacity(0.4),
                            radius: 1, x: 0, y: 1
                        )
                }
            }
            // Selected lifts slightly
            .offset(y: isSelected && !justCompleted ? -6 : 0)
            .scaleEffect(justCompleted ? 1.12 : (isSelected ? 1.08 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: justCompleted)
        }
        .buttonStyle(.plain)
        .disabled(justCompleted)
        .accessibilityLabel("Color \(group.id + 1)\(remaining == 0 ? ", completed" : ", \(remaining) of \(total) remaining")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Color Helpers

    private static func relativeLuminance(hex: String) -> Double {
        let (r, g, b) = rgb(from: hex)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func lighterTint(hex: String) -> Color {
        let (r, g, b) = rgb(from: hex)
        let hsb = rgbToHSB(r: r, g: g, b: b)
        return Color(
            hue: Double(hsb.hue),
            saturation: Double(min(hsb.saturation * 1.1, 1.0)),
            brightness: Double(min(hsb.brightness + 0.45, 1.0))
        )
    }

    private static func rgb(from hex: String) -> (Double, Double, Double) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6,
              let val = UInt64(cleaned, radix: 16) else { return (0.5, 0.5, 0.5) }
        return (
            Double((val >> 16) & 0xFF) / 255.0,
            Double((val >> 8) & 0xFF) / 255.0,
            Double(val & 0xFF) / 255.0
        )
    }

    // MARK: - Counts

    private func remainingCount(for group: SVGColorGroup) -> Int {
        group.elementIndices.count - group.elementIndices.filter { filledElements.contains($0) }.count
    }

    private var completedGroupCount: Int {
        groups.filter { remainingCount(for: $0) == 0 }.count
    }

    private var swatchSpacing: CGFloat {
        isIPad ? 16 : 14
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
