import SwiftUI

/// "How it feels": noise, light, crowds and smells right now, each with a five-step meter,
/// followed by heads-up chips for triggers that match the user's profile.
struct HowItFeelsCard: View {
    let place: Place
    let engine: TideEngine
    let minute: Int

    private struct Row: Identifiable {
        let factor: Factor
        let title: String
        let symbol: String

        var id: Factor { factor }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    private static let rows = [
        Row(factor: .noise, title: "Noise", symbol: "speaker.wave.2"),
        Row(factor: .light, title: "Light", symbol: "sun.max"),
        Row(factor: .crowd, title: "Crowds", symbol: "person.2"),
        Row(factor: .smell, title: "Smells", symbol: "nose"),
    ]

    var body: some View {
        // When closed, describe the place as it usually is when it opens.
        let moment = place.hours.isOpen(at: minute) ? minute : place.hours.opens
        let levels = place.forecast.levels(at: Double(moment))
        let headsUps = engine.headsUps(for: place)

        Card {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Self.rows) { row in
                    let description = TideText.feeling(row.factor, at: place, minute: moment)
                    let level = TideText.meterLevel(levels[row.factor])
                    Group {
                        if dynamicTypeSize.isAccessibilitySize {
                            // Stacked, so the title and description get the full width.
                            VStack(alignment: .leading, spacing: 6) {
                                feelingText(title: row.title, description: description)
                                StepMeter(level: level)
                            }
                        } else {
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: row.symbol)
                                    .font(.body)
                                    .foregroundStyle(.inkSecondary)
                                    .frame(width: iconWidth)
                                    .accessibilityHidden(true)
                                feelingText(title: row.title, description: description)
                                Spacer(minLength: 8)
                                StepMeter(level: level)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(row.title): \(description). Level \(level) out of 5.")
                    if row.factor != Self.rows.last?.factor {
                        Hairline()
                    }
                }

                if !headsUps.isEmpty {
                    Text("Heads-up for your profile")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.ink)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .accessibilityAddTraits(.isHeader)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(headsUps, id: \.self) { trigger in
                            HeadsUpChip(text: trigger.label)
                        }
                    }
                }
            }
        }
    }
}

extension HowItFeelsCard {
    private func feelingText(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.ink)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "Good to know": quiet hours, quiet rooms, access and so on.
struct GoodToKnowCard: View {
    let place: Place

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    var body: some View {
        let lines = Self.lines(for: place)
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: 12) {
                        // The icon is decorative; at accessibility sizes the text gets the full width.
                        if !dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: line.kind.symbolName)
                                .font(.body)
                                .foregroundStyle(.calmDeep)
                                .frame(width: iconWidth)
                                .accessibilityHidden(true)
                        }
                        Text(line.text)
                            .font(.body)
                            .foregroundStyle(.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    if index < lines.count - 1 {
                        Hairline()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    /// The quiet hour (if any) first, then the place's own lines.
    static func lines(for place: Place) -> [GoodToKnow] {
        var lines = place.goodToKnow
        if let quietHour = place.quietHour {
            let quiet = GoodToKnow(kind: .quietHour, text: TideText.quietHour(quietHour))
            lines.insert(quiet, at: min(1, lines.count))
        }
        return lines
    }
}

#Preview("How it feels") {
    ScrollView {
        VStack(spacing: 16) {
            HowItFeelsCard(
                place: PreviewSupport.place(),
                engine: TideEngine(profile: PreviewSupport.mockupProfile),
                minute: 14 * 60
            )
            GoodToKnowCard(place: PreviewSupport.place())
        }
        .padding()
    }
    .background(Color.ground)
}
