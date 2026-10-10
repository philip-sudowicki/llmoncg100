import SwiftUI

/// "How's the tide?": a quick check-in kept on this iPhone.
struct CheckInView: View {
    let place: Place

    @Environment(PersonalStore.self) private var personalStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(PlaceStore.self) private var placeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var feeling: CheckInFeeling?
    @State private var noticed: Set<NoticedThing> = []
    @State private var meter = SoundMeter()
    @State private var confirmations = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How's the tide?")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(place.name) · right now")
                            .font(.subheadline)
                            .foregroundStyle(.inkSecondary)
                    }

                    feelingChoices

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("What did you notice?")
                                .font(.headline)
                                .foregroundStyle(.ink)
                                .accessibilityAddTraits(.isHeader)
                            Spacer(minLength: 8)
                            Text("Optional")
                                .font(.footnote)
                                .foregroundStyle(.inkSecondary)
                        }
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(NoticedThing.allCases) { thing in
                                Chip(title: thing.title, isSelected: noticed.contains(thing)) {
                                    if noticed.contains(thing) {
                                        noticed.remove(thing)
                                    } else {
                                        noticed.insert(thing)
                                    }
                                }
                            }
                        }
                    }

                    if profileStore.profile.shareSoundReadings {
                        SoundMeterCard(meter: meter)
                    } else {
                        Text("Sound readings are off in your Tide profile.")
                            .font(.subheadline)
                            .foregroundStyle(.inkSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.surface)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button("Share check-in") {
                        save()
                    }
                    .buttonStyle(.primary)
                    .disabled(feeling == nil)
                    Text("Anonymous. Not linked to your name or profile.")
                        .font(.footnote)
                        .foregroundStyle(.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.surface)
            }
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        meter.cancel()
                        dismiss()
                    }
                }
            }
        }
        // The app's only haptic: a gentle tap to confirm the check-in was kept.
        .sensoryFeedback(.impact(weight: .light), trigger: confirmations)
        .presentationCornerRadius(26)
        .presentationDragIndicator(.visible)
        .onDisappear {
            meter.cancel()
        }
    }

    private var feelingChoices: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            ForEach(CheckInFeeling.allCases) { option in
                FeelingCard(feeling: option, isSelected: feeling == option) {
                    feeling = option
                }
            }
        }
    }

    private func save() {
        guard let feeling else { return }
        let decibels = profileStore.profile.shareSoundReadings && meter.phase == .finished ? meter.result : nil
        personalStore.addCheckIn(placeID: place.id, feeling: feeling, noticed: noticed, decibels: decibels, at: placeStore.now)
        confirmations += 1
        AccessibilityNotification.Announcement("Check-in saved for \(place.name).").post()
        meter.cancel()
        dismiss()
    }
}

/// One of Calm / Okay / Too much. Only one can be selected.
private struct FeelingCard: View {
    let feeling: CheckInFeeling
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .headline) private var badgeSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                StatusBadge(status: feeling.status, size: badgeSize)
                Text(feeling.title)
                    .font(.headline)
                    .foregroundStyle(.ink)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.calmTint : Color.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.calmDeep : Color.divider, lineWidth: isSelected ? 2.5 : 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Check-in") {
    Color.ground
        .sheet(isPresented: .constant(true)) {
            CheckInView(place: PreviewSupport.place())
        }
        .previewEnvironment()
}

#Preview("Check-in, dark, large text") {
    Color.ground
        .sheet(isPresented: .constant(true)) {
            CheckInView(place: PreviewSupport.place())
        }
        .previewEnvironment()
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
