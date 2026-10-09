import SwiftUI

// Colour tokens live in Assets.xcassets (with dark and Increase Contrast variants) and are used
// through Xcode's generated symbols, for example `Color.ink` or `.foregroundStyle(.calmDeep)`.

/// Shared sizes. Text always uses Dynamic Type styles; these are for shapes and tap targets.
enum Metrics {
    static let tileRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 16
    static let cardRadius: CGFloat = 18
    static let sheetRadius: CGFloat = 26
    static let minimumTapTarget: CGFloat = 44
}

extension TideStatus {
    var color: Color {
        switch self {
        case .calm: .calm
        case .busy: .busy
        case .high: .high
        }
    }

    /// The colour for glyphs drawn on `color`.
    var onColor: Color {
        switch self {
        case .calm: .onCalm
        case .busy: .onBusy
        case .high: .onHigh
        }
    }

    /// Background for banners in this status.
    var tint: Color {
        switch self {
        case .calm: .calmTint
        case .busy: .busyTint
        case .high: .highTint
        }
    }

    /// Text colour on `tint`.
    var tintText: Color {
        switch self {
        case .calm: .ink
        case .busy: .busyText
        case .high: .highText
        }
    }
}

/// A rounded, softly shadowed card on `surface`.
struct CardModifier: ViewModifier {
    var padding: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .fill(Color.surface)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Color.divider, lineWidth: contrast == .increased ? 1.5 : 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

/// A rounded square holding an SF Symbol, used for categories and actions.
struct IconTile: View {
    let systemImage: String
    var background: Color = .calmTint
    var foreground: Color = .calmDeep
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(foreground)
            }
            .accessibilityHidden(true)
    }
}

/// A section title with an optional trailing note: "Today's tide · Friday · for you".
struct SectionHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                heading
                Spacer(minLength: 12)
                trailing
            }
            VStack(alignment: .leading, spacing: 4) {
                heading
                trailing
            }
        }
    }

    private var heading: some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(Color.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeading where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// A small uppercase label for grouped settings: "WHAT GETS TO YOU".
struct GroupLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.inkSecondary)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}
