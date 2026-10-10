import SwiftUI

/// Full-width filled button in `calmDeep`, used for the main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.onCalmDeep)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.calmDeep, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Full-width outlined button, for secondary actions such as "How's the tide?".
struct OutlinedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.calmDeep)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(configuration.isPressed ? Color.calmTint : Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.calmDeep, lineWidth: contrast == .increased ? 2 : 1.5)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == OutlinedButtonStyle {
    static var outlined: OutlinedButtonStyle { OutlinedButtonStyle() }
}

/// The look of the four equal buttons on the place page: an icon above a short label.
/// Shared by `ActionTile` and `ShareLink`, which can't be a plain `Button`.
struct ActionTileLabel: View {
    let title: String
    let systemImage: String
    var isProminent = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
                .accessibilityHidden(true)
            Text(title)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .foregroundStyle(isProminent ? Color.onCalmDeep : Color.calmDeep)
        .background(
            isProminent ? Color.calmDeep : Color.calmTint,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// One of the four equal buttons on the place page.
struct ActionTile: View {
    let title: String
    let systemImage: String
    var isProminent = false
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ActionTileLabel(title: title, systemImage: systemImage, isProminent: isProminent)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A 44 pt circular icon button, used for close and profile buttons.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var foreground: Color = .ink
    var background: Color = .ground
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(width: min(max(44, size), 60), height: min(max(44, size), 60))
                .background(background, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview("Buttons") {
    ScrollView {
        VStack(spacing: 16) {
            Button {} label: {
                Label("Find low water", systemImage: "water.waves")
            }
            .buttonStyle(.primary)

            Button {} label: {
                Label("How's the tide?", systemImage: "plus.circle")
            }
            .buttonStyle(.outlined)

            HStack(spacing: 8) {
                ActionTile(title: "Directions", systemImage: "arrow.triangle.turn.up.right.diamond", isProminent: true) {}
                ActionTile(title: "Alert me", systemImage: "bell") {}
                ActionTile(title: "Save", systemImage: "bookmark") {}
                ActionTile(title: "Share", systemImage: "square.and.arrow.up") {}
            }

            HStack {
                CircleIconButton(systemImage: "xmark", label: "Close") {}
                CircleIconButton(systemImage: "person.crop.circle", label: "Tide profile", background: .surface) {}
            }
        }
        .padding()
    }
    .background(Color.ground)
}
