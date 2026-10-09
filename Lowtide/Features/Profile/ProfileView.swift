import SwiftUI

/// The Tide profile. Shown as onboarding on first launch, then from the map's profile button.
/// Saving updates `ProfileStore`, which recolours every pin straight away.
struct ProfileView: View {
    enum Mode {
        case onboarding
        case edit
    }

    let mode: Mode

    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = SensoryProfile.standard
    @State private var hasLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "What gets to you")
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Factor.allCases) { factor in
                                SensitivityRow(factor: factor, selection: $draft[factor])
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                if factor != Factor.allCases.last {
                                    Hairline()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "What helps")
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(Help.allCases) { help in
                            Chip(title: help.title, isSelected: draft.helps.contains(help)) {
                                if draft.helps.contains(help) {
                                    draft.helps.remove(help)
                                } else {
                                    draft.helps.insert(help)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Alerts and sharing")
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            Toggle(isOn: $draft.gentleAlerts) {
                                ToggleLabel(title: "Gentle alerts", detail: "Off until you turn it on. Silent alerts, only when you tap Alert me.")
                            }
                            .toggleStyle(.row)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            Hairline().padding(.leading, 16)
                            Toggle(isOn: $draft.shareSoundReadings) {
                                ToggleLabel(title: "Share sound readings", detail: "Only the decibel number")
                            }
                            .toggleStyle(.row)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            Hairline().padding(.leading, 16)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Trusted person")
                                    .font(.headline)
                                    .foregroundStyle(.ink)
                                TextField(text: $draft.trustedPerson, prompt: Text("Name (optional)").foregroundStyle(.inkSecondary)) {
                                    Text("Trusted person")
                                }
                                .textContentType(.name)
                                .submitLabel(.done)
                                .foregroundStyle(.ink)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(Color.ground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Text("Find low water offers a button to tell this person where you are.")
                                    .font(.footnote)
                                    .foregroundStyle(.inkSecondary)
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .tint(.calmDeep)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ground)
        .safeAreaInset(edge: .bottom) {
            Button("Save profile") {
                profileStore.save(draft)
                if mode == .edit {
                    dismiss()
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.ground)
        }
        .onAppear {
            guard !hasLoaded else { return }
            draft = profileStore.profile
            hasLoaded = true
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            if mode == .edit {
                Button {
                    dismiss()
                } label: {
                    Label("Map", systemImage: "chevron.left")
                        .font(.body)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.calmDeep)
                .accessibilityLabel("Back to map without saving")
            } else {
                Text("Welcome to Lowtide")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.calmDeep)
            }

            Text("Tide profile")
                .font(.largeTitle.bold())
                .foregroundStyle(.ink)
                .accessibilityAddTraits(.isHeader)

            Text("Tell Lowtide what gets to you. Every place on the map is coloured for you.")
                .font(.body)
                .foregroundStyle(.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("Stays on this iPhone. Never uploaded.", systemImage: "lock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.calmDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.calmTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// A factor with its A bit / Some / A lot picker. Stacks vertically at accessibility text sizes.
private struct SensitivityRow: View {
    let factor: Factor
    @Binding var selection: Sensitivity

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let picker = SegmentedChoice(
            title: factor.profileTitle,
            options: Sensitivity.allCases,
            label: \.title,
            selection: $selection
        )

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                title
                picker
            }
        } else {
            HStack(spacing: 12) {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                picker
                    .frame(width: 210)
            }
        }
    }

    private var title: some View {
        Text(factor.profileTitle)
            .font(.headline)
            .foregroundStyle(.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ToggleLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.ink)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Onboarding") {
    ProfileView(mode: .onboarding)
        .previewEnvironment(onboarded: false)
}

#Preview("Edit profile") {
    ProfileView(mode: .edit)
        .previewEnvironment()
}
