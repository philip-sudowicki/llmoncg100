import SwiftUI

/// The large filled button in `calmDeep`, such as "Find low water" or "Save profile".
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.onCalmDeep)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .fill(Color.calmDeep)
            )
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
    }
}

/// The outlined button, such as "How's the tide?" or "Start reading".
struct OutlinedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.calmDeep)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .fill(configuration.isPressed ? Color.calmTint : Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .strokeBorder(Color.calmDeep, lineWidth: contrast == .increased ? 2.5 : 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// One of the four equal buttons on the place page (Directions, Alert me, Save, Share).
struct ActionButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isProminent ? Color.onCalmDeep : Color.calmDeep)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .fill(isProminent ? Color.calmDeep : Color.calmTint)
            )
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Icon above title, for `ActionButtonStyle`. Lays out side by side at accessibility sizes.
struct ActionLabel: View {
    let title: String
    let systemImage: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 6))
        layout {
            Image(systemName: systemImage)
                .font(.title3)
                .accessibilityHidden(true)
            Text(title)
        }
    }
}

/// How a selected chip is filled.
enum ChipTone {
    /// Dark `ink` fill: filters and check-in notes.
    case ink
    /// `calmDeep` fill: the profile's "What helps".
    case calm
}

/// A selectable capsule, at least 44 pt tall. Selection shows a checkmark as well as a fill,
/// and VoiceOver hears "Selected".
struct Chip<Leading: View>: View {
    let title: String
    let isSelected: Bool
    var tone: ChipTone = .ink
    var unselectedFill: Color = .surface
    @ViewBuilder var leading: Leading
    let action: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.bold))
                        .accessibilityHidden(true)
                }
                leading
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? selectedText : Color.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: Metrics.minimumTapTarget)
            .background(Capsule().fill(isSelected ? selectedFill : unselectedFill))
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.clear : Color.divider,
                    lineWidth: contrast == .increased ? 1.5 : 1
                )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedFill: Color {
        switch tone {
        case .ink: .ink
        case .calm: .calmDeep
        }
    }

    private var selectedText: Color {
        switch tone {
        case .ink: .inkInverse
        case .calm: .onCalmDeep
        }
    }
}

extension Chip where Leading == EmptyView {
    init(
        _ title: String,
        isSelected: Bool,
        tone: ChipTone = .ink,
        unselectedFill: Color = .surface,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title, isSelected: isSelected, tone: tone, unselectedFill: unselectedFill,
            leading: { EmptyView() }, action: action
        )
    }
}

/// A non-interactive heads-up chip: "Hand dryer in toilets".
struct HeadsUpChip: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "exclamationmark.circle")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Color.busyText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.busyTint))
    }
}

/// A five-step meter, such as noise level. Each step is a small rounded bar.
struct StepMeter: View {
    let filled: Int
    var total = 5
    var tint: Color = .calm

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < filled ? tint : Color.divider)
                    .frame(width: 5, height: 16)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled) of \(total)")
    }
}

#Preview("Controls") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Button("Find low water") {}.buttonStyle(PrimaryButtonStyle())
            Button("How's the tide?") {}.buttonStyle(OutlinedButtonStyle())
            HStack {
                Button {} label: { ActionLabel(title: "Directions", systemImage: "arrow.triangle.turn.up.right.diamond") }
                    .buttonStyle(ActionButtonStyle(isProminent: true))
                Button {} label: { ActionLabel(title: "Alert me", systemImage: "bell") }
                    .buttonStyle(ActionButtonStyle())
            }
            HStack {
                Chip("Calm now", isSelected: true) {}
                Chip("Cafés", isSelected: false) {}
                Chip("Natural light", isSelected: true, tone: .calm) {}
            }
            HeadsUpChip(text: "Hand dryer in toilets")
            StepMeter(filled: 2)
        }
        .padding()
    }
    .background(Color.ground)
}
