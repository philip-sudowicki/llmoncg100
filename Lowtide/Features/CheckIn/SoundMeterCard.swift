import SwiftUI

/// "Measure the sound": a 10-second reading. Only the number is kept.
struct SoundMeterCard: View {
    let meter: SoundMeter

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mic")
                    .font(.title3)
                    .foregroundStyle(.calmDeep)
                    .frame(width: iconSize, height: iconSize)
                    .background(Color.surface, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Measure the sound")
                        .font(.headline)
                        .foregroundStyle(.ink)
                    Text("Takes 10 seconds. Only the number is kept. No audio is recorded, stored or uploaded.")
                        .font(.subheadline)
                        .foregroundStyle(.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            switch meter.phase {
            case .idle:
                Button("Start reading") {
                    meter.start()
                }
                .buttonStyle(.outlined)

            case .measuring:
                HStack(spacing: 12) {
                    StepMeter(level: meter.liveDecibels.map(SoundLevel.meterLevel) ?? 1)
                    Text(meter.liveDecibels.map { "Listening · about \(Int($0.rounded())) dB" } ?? "Listening…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.ink)
                        .monospacedDigit()
                    Spacer(minLength: 8)
                    Text("\(meter.secondsLeft) s left")
                        .font(.subheadline)
                        .foregroundStyle(.inkSecondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Measuring. \(meter.secondsLeft) seconds left.")
                Button("Stop") {
                    meter.cancel()
                }
                .buttonStyle(.outlined)

            case .finished:
                if let result = meter.result {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(result.rounded())) dB · \(SoundLevel.describe(result))")
                                .font(.headline)
                                .foregroundStyle(.ink)
                            Text("Approximate. Added to this check-in.")
                                .font(.footnote)
                                .foregroundStyle(.inkSecondary)
                        }
                        Spacer(minLength: 8)
                        StepMeter(level: SoundLevel.meterLevel(result))
                    }
                    .accessibilityElement(children: .combine)
                }
                Button("Measure again") {
                    meter.start()
                }
                .buttonStyle(.outlined)

            case .denied:
                Text("Microphone access is off for Lowtide. You can allow it in Settings, or check in without a reading.")
                    .font(.subheadline)
                    .foregroundStyle(.ink)
                    .fixedSize(horizontal: false, vertical: true)

            case .unavailable:
                Text("The microphone isn't available right now.")
                    .font(.subheadline)
                    .foregroundStyle(.ink)
                Button("Try again") {
                    meter.start()
                }
                .buttonStyle(.outlined)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: meter.phase) { _, phase in
            if phase == .finished, let result = meter.result {
                AccessibilityNotification.Announcement("\(Int(result.rounded())) decibels. \(SoundLevel.describe(result)).").post()
            }
        }
    }
}

#Preview("Sound meter") {
    SoundMeterCard(meter: SoundMeter())
        .padding()
        .background(Color.surface)
}
