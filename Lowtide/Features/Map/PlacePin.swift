import SwiftUI

/// A map pin: a white capsule with the status circle and the place name.
struct PlacePin: View {
    let name: String
    let status: TideStatus?
    var isSelected = false
    let action: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var badgeSize: CGFloat = 22
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                StatusBadge(status: status, size: badgeSize)
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.ink)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.leading, 5)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background(Color.surface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.calmDeep : (contrast == .increased ? Color.ink : Color.clear),
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .shadow(color: .black.opacity(0.16), radius: 6, y: 2)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Shows the tide forecast")
        // Pins stay legible on the map at very large text sizes; the list below the map has no cap.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// Calm / Busy / High tide, each with its glyph.
struct TideLegend: View {
    @ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TideStatus.allCases) { status in
                HStack(spacing: 4) {
                    StatusBadge(status: status, size: badgeSize)
                    Text(status.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.ink)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.surface, in: Capsule())
        .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend: one wave means calm, two waves busy, three waves high tide")
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

#Preview("Pins") {
    VStack(spacing: 12) {
        PlacePin(name: "Marlow Library", status: .calm) {}
        PlacePin(name: "Fern & Finch", status: .busy) {}
        PlacePin(name: "Northgate Market", status: .high, isSelected: true) {}
        PlacePin(name: "The Harbour Room", status: nil) {}
        TideLegend()
    }
    .padding()
    .background(Color.ground)
}
