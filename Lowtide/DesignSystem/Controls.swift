import SwiftUI

/// A segmented control with 44 pt segments. The system segmented control is about 32 pt tall,
/// below the app's minimum tap target, so this draws its own segments. VoiceOver and other
/// assistive technologies see a standard segmented `Picker`.
struct SegmentedChoice<Value: Hashable & Identifiable>: View {
    let title: String
    let options: [Value]
    let label: (Value) -> String
    @Binding var selection: Value

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.surface)
                                    .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(contrast == .increased ? Color.ink : Color.divider, lineWidth: 1)
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.ground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityRepresentation {
            Picker(title, selection: $selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// A toggle whose whole row (at least 44 pt tall) is the tap target, not only the switch.
/// Assistive technologies still see a standard switch.
struct RowToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("", isOn: configuration.$isOn)
                    .labelsHidden()
                    .allowsHitTesting(false)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
        }
    }
}

extension ToggleStyle where Self == RowToggleStyle {
    static var row: RowToggleStyle { RowToggleStyle() }
}

#Preview("Controls") {
    struct Demo: View {
        @State private var sensitivity = Sensitivity.some
        @State private var isOn = false

        var body: some View {
            VStack(spacing: 20) {
                SegmentedChoice(title: "Loud noise", options: Sensitivity.allCases, label: \.title, selection: $sensitivity)
                Toggle(isOn: $isOn) {
                    Text("Gentle alerts").foregroundStyle(.ink)
                }
                .toggleStyle(.row)
                .tint(.calmDeep)
            }
            .padding()
            .background(Color.surface)
        }
    }
    return Demo()
}
