import SwiftUI

/// The Tide profile. It is the first-launch onboarding, then it's reachable from the map.
///
/// Edits apply straight away, so the map behind recolours live. Save profile stores them.
struct TideProfileView: View {
    enum Mode {
        case onboarding
        case editing
    }

    let mode: Mode

    @Environment(ProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if mode == .editing {
                    Button {
                        finish()
                    } label: {
                        Label("Map", systemImage: "chevron.left")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.calmDeep)
                            .frame(minHeight: Metrics.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to map")
                }

                intro

                VStack(alignment: .leading, spacing: 8) {
                    GroupLabel("What gets to you")
                    VStack(spacing: 0) {
                        ForEach(Array(Factor.allCases.enumerated()), id: \.element) { index, factor in
                            if index > 0 { Divider() }
                            SensitivityRow(factor: factor, selection: $store.profile[sensitivity: factor])
                        }
                    }
                    .card(padding: 16)
                }

                VStack(alignment: .leading, spacing: 10) {
                    GroupLabel("What helps")
                    FlowLayout {
                        ForEach(Help.allCases) { help in
                            Chip(help.label, isSelected: store.profile.helps.contains(help), tone: .calm) {
                                if store.profile.helps.contains(help) {
                                    store.profile.helps.remove(help)
                                } else {
                                    store.profile.helps.insert(help)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    GroupLabel("Alerts and sharing")
                    VStack(spacing: 0) {
                        Toggle(isOn: $store.profile.gentleAlerts) {
                            ToggleLabel(title: "Gentle alerts", detail: "Off until you turn it on. Alert me uses this.")
                        }
                        .padding(.vertical, 10)
                        Divider()
                        Toggle(isOn: $store.profile.shareSoundReadings) {
                            ToggleLabel(title: "Share sound readings", detail: "Only the decibel number, never audio")
                        }
                        .padding(.vertical, 10)
                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Trusted person")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.ink)
                            TextField("Name (optional)", text: $store.profile.trustedPerson)
                                .textContentType(.name)
                                .submitLabel(.done)
                                .foregroundStyle(Color.ink)
                                .frame(minHeight: Metrics.minimumTapTarget)
                            Text("Find low water can message them for you.")
                                .font(.footnote)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        .padding(.vertical, 10)
                    }
                    .tint(Color.calmDeep)
                    .card(padding: 16)
                }

                Button("Save profile", action: finish)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ground)
        .onDisappear {
            // Swiping the sheet away keeps the changes too.
            if mode == .editing { store.save() }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tide profile")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Tell Lowtide what gets to you. Every place on the map is coloured for you.")
                .font(.body)
                .foregroundStyle(Color.inkSecondary)
            Label("Stays on this iPhone. Never uploaded.", systemImage: "lock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Color.calmTint)
                )
        }
    }

    private func finish() {
        store.save()
        if mode == .editing { dismiss() }
    }
}

/// "Loud noise · A bit / Some / A lot". Stacks vertically at large text sizes.
private struct SensitivityRow: View {
    let factor: Factor
    @Binding var selection: Sensitivity
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Text(factor.profileLabel)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            Picker(factor.profileLabel, selection: $selection) {
                ForEach(Sensitivity.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: Metrics.minimumTapTarget)
            .frame(maxWidth: dynamicTypeSize >= .xxLarge ? .infinity : 190)
        }
        .padding(.vertical, 10)
    }
}

private struct ToggleLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ink)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color.inkSecondary)
        }
    }
}

#Preview("Onboarding") {
    TideProfileView(mode: .onboarding)
        .previewEnvironment(hasSavedProfile: false)
}

#Preview("Editing") {
    TideProfileView(mode: .editing)
        .previewEnvironment()
}
