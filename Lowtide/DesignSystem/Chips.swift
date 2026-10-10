import SwiftUI

/// A 44 pt capsule toggle used for filters, "What did you notice?" and "What helps".
struct Chip: View {
    let title: String
    let isSelected: Bool
    /// Shows a tick when selected, for multi-select groups.
    var showsCheckmark = true
    var glyph: TideStatus? = nil
    var floating = false
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    /// A capsule at one line; long labels at large text sizes wrap inside the same rounded shape.
    private static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let glyph {
                    StatusGlyph(status: glyph, color: isSelected ? .surface : glyph.fill)
                } else if isSelected, showsCheckmark {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? Color.surface : Color.ink)
            .background(isSelected ? Color.ink : Color.surface, in: Self.shape)
            .overlay(
                Self.shape.strokeBorder(
                    isSelected ? Color.clear : Color.divider,
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            )
            .shadow(color: floating ? Color.black.opacity(0.10) : .clear, radius: 6, y: 2)
            .contentShape(Self.shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small warning chip for heads-up triggers, for example "Hand dryer in toilets".
struct HeadsUpChip: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle")
                .font(.subheadline)
        }
        .foregroundStyle(.busyText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.busyTint, in: Capsule())
        .accessibilityLabel("Heads-up: \(text)")
    }
}

/// A small rounded label, for example "Good match for you".
struct Pill: View {
    let text: String
    var foreground: Color = .calmDeep
    var background: Color = .calmTint

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
    }
}

/// Lays chips out in rows, wrapping to the next line when they run out of room.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, maxWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(subviews, maxWidth: bounds.width).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            size.width = min(size.width, maxWidth)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (frames, CGSize(width: widest, height: y + lineHeight))
    }
}

#Preview("Chips") {
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            Chip(title: "Calm now", isSelected: true, glyph: .calm) {}
            Chip(title: "Cafés", isSelected: false) {}
        }
        FlowLayout {
            ForEach(["Music", "Chatter", "Hand dryer", "Coffee machine", "Bright lights", "Flicker"], id: \.self) { item in
                Chip(title: item, isSelected: item == "Chatter") {}
            }
        }
        HeadsUpChip(text: "Closing bell at 6:45pm")
        Pill(text: "Good match for you")
    }
    .padding()
    .background(Color.ground)
}
