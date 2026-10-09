import SwiftData
import SwiftUI
import UIKit

/// "How's the tide?": a quick, anonymous check-in for one place.
struct CheckInView: View {
    let place: Place

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var feeling: CheckInFeeling?
    @State private var noticed: Set<NoticedTrigger> = []
    @State private var meter = SoundMeter()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How's the tide?")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(place.name) · right now")
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }

                    feelingChoices

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("What did you notice?")
                                .font(.headline)
                                .foregroundStyle(Color.ink)
                                .accessibilityAddTraits(.isHeader)
                            Spacer()
                            Text("Optional")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkSecondary)
                        }
                        FlowLayout {
                            ForEach(NoticedTrigger.allCases) { trigger in
                                Chip(trigger.label, isSelected: noticed.contains(trigger), unselectedFill: .ground) {
                                    if noticed.contains(trigger) {
                                        noticed.remove(trigger)
                                    } else {
                                        noticed.insert(trigger)
                                    }
                                }
                            }
                        }
                    }

                    SoundMeterCard(meter: meter, keepsReading: profileStore.profile.shareSoundReadings)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button("Share check-in", action: submit)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(feeling == nil)
                        .accessibilityHint(feeling == nil ? "Choose how it feels first" : "")
                    Text("Anonymous. Not linked to your name or profile.")
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color.surface)
            }
            .background(Color.surface)
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Color.calmDeep)
        .presentationCornerRadius(Metrics.sheetRadius)
        .onDisappear { meter.cancel() }
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

    private func submit() {
        guard let feeling else { return }
        var decibels: Double?
        if profileStore.profile.shareSoundReadings, case .finished(let reading) = meter.phase {
            decibels = reading
        }
        meter.cancel()
        modelContext.insert(
            CheckIn(placeID: place.id, feeling: feeling, noticed: Array(noticed), decibels: decibels)
        )
        try? modelContext.save()
        // The app's only haptic: one gentle tap to confirm.
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        dismiss()
    }
}

/// Calm, Okay or Too much: a large single-choice card with its glyph.
private struct FeelingCard: View {
    let feeling: CheckInFeeling
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                StatusBadge(status: feeling.status, size: 44)
                Text(feeling.title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .fill(isSelected ? Color.calmTint : Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.calmDeep : Color.divider,
                        lineWidth: isSelected ? 2.5 : (contrast == .increased ? 1.5 : 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.calmDeep)
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feeling.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "Measure the sound": a ten-second reading. Only the number is kept.
struct SoundMeterCard: View {
    let meter: SoundMeter
    /// Whether the reading is attached to the check-in, from "Share sound readings".
    let keepsReading: Bool
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "mic")
                    .font(.title3)
                    .foregroundStyle(Color.calmDeep)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.surface))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Measure the sound")
                        .font(.headline)
                        .foregroundStyle(Color.ink)
                    Text("Takes 10 seconds. Only the number is kept. No audio is recorded, saved or uploaded.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                    if !keepsReading {
                        Text("Share sound readings is off in your Tide profile, so the number stays on this screen.")
                            .font(.footnote)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Color.ground))
    }

    @ViewBuilder
    private var content: some View {
        switch meter.phase {
        case .idle:
            Button("Start reading") { meter.start() }
                .buttonStyle(OutlinedButtonStyle())
        case .measuring(let secondsLeft):
            HStack {
                Text("Listening… \(secondsLeft) s left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .monospacedDigit()
                Spacer()
                StepMeter(filled: steps(for: meter.liveDecibels))
            }
            .accessibilityElement(children: .combine)
            Button("Stop") { meter.cancel() }
                .buttonStyle(OutlinedButtonStyle())
        case .finished(let decibels):
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(decibels.rounded())) dB")
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                    Text(SoundLevel.description(forDecibels: decibels))
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
                Spacer()
                StepMeter(filled: steps(for: decibels))
            }
            .accessibilityElement(children: .combine)
            Button("Measure again") { meter.start() }
                .buttonStyle(OutlinedButtonStyle())
        case .denied:
            Text("Lowtide can't use the microphone. You can allow it in Settings.")
                .font(.subheadline)
                .foregroundStyle(Color.ink)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(OutlinedButtonStyle())
        case .failed:
            Text("The microphone isn't available right now.")
                .font(.subheadline)
                .foregroundStyle(Color.ink)
            Button("Try again") { meter.start() }
                .buttonStyle(OutlinedButtonStyle())
        }
    }

    private func steps(for decibels: Double?) -> Int {
        FeelText.meterSteps(TideEngine.normalisedNoise(decibels: decibels ?? SoundLevel.minimumDecibels))
    }
}

#Preview("Check-in") {
    CheckInView(place: PreviewData.library)
        .previewEnvironment()
}
