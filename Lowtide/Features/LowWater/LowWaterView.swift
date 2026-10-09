import MapKit
import SwiftUI

/// For someone who is overwhelmed right now: gentle, simple and fast. Always dark.
struct LowWaterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(LocationService.self) private var location
    @Environment(TideClock.self) private var clock
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var finder = LowWaterFinder()
    @State private var isShowingCards = false

    private var origin: GeoPoint? { location.current ?? placeStore.anchor }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                topBar
                BreathingCircle()
                VStack(spacing: 6) {
                    Text("You're doing fine.")
                        .font(.title2.bold())
                        .foregroundStyle(Color.lowWaterText)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Color.lowWaterTextSecondary)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)

                resultCard
                actions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.lowWaterBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .task { await find() }
        .fullScreenCover(isPresented: $isShowingCards) {
            StaffCardsView()
        }
    }

    private var subtitle: String {
        switch finder.phase {
        case .searching:
            "Looking for calm water nearby."
        case .found(let result):
            "A calm place is \(Walking.spokenMinutes(result.minutes)) away."
        case .nothingCalm:
            "Nothing calm is open nearby right now. You can still show a card or tell someone."
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.lowWaterText)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.lowWaterCard))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            Text("Low water")
                .font(.headline)
                .foregroundStyle(Color.lowWaterText)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Label("Dimmed", systemImage: "moon.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lowWaterTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.lowWaterCard))
                .accessibilityLabel("Dimmed screen")
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        switch finder.phase {
        case .searching:
            Text("Checking walking times to the nearest calm places…")
                .font(.subheadline)
                .foregroundStyle(Color.lowWaterTextSecondary)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Color.lowWaterCard))
        case .found(let result):
            LowWaterCard(result: result, origin: origin ?? result.destination)
        case .nothingCalm:
            EmptyView()
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if case .found(let result) = finder.phase {
                Button {
                    DirectionsService.openWalkingDirections(to: result.destination, name: result.place.name)
                } label: {
                    Text("Start walking")
                        .font(.headline)
                        .foregroundStyle(Color.lowWaterBackground)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                                .fill(Color.lowWaterAccent)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens walking directions to \(result.place.name) in Maps")
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Button {
                    isShowingCards = true
                } label: {
                    LowWaterSecondaryLabel(title: "Show a card", systemImage: "text.bubble")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows large messages you can show to staff")

                ShareLink(item: tellMessage) {
                    LowWaterSecondaryLabel(title: tellTitle, systemImage: "person")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Sends a message with your location")
            }
        }
    }

    private var tellTitle: String {
        profileStore.profile.trustedPersonName.map { "Tell \($0)" } ?? "Tell someone"
    }

    private var tellMessage: String {
        let message = "I'm feeling overwhelmed, so I'm finding somewhere calm. I'm okay."
        guard let here = location.current ?? placeStore.anchor else { return message }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(here.latitude),\(here.longitude)"),
            URLQueryItem(name: "q", value: "My location"),
        ]
        guard let link = components?.url?.absoluteString else { return message }
        return "\(message) This is where I am: \(link)"
    }

    private func find() async {
        if DemoOptions.screen == .cards {
            try? await Task.sleep(for: .seconds(1))
            isShowingCards = true
        }
        guard let anchor = placeStore.anchor, let origin else { return }
        await finder.find(
            places: placeStore.places,
            engine: TideEngine(profile: profileStore.profile),
            minute: clock.minuteOfDay,
            origin: origin,
            anchor: anchor
        )
    }
}

private struct LowWaterSecondaryLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(Color.lowWaterText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous).fill(Color.lowWaterCard))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
    }
}

/// "Nearest low water": the place, walking time, a small route map and the first instruction.
private struct LowWaterCard: View {
    let result: LowWaterResult
    let origin: GeoPoint

    private var quietLine: String {
        switch result.change {
        case .calmUntil(let minute): "Calm now · quiet until \(TimeText.time(minute))"
        case .calmUntilClosing(let minute): "Calm now · quiet until it closes at \(TimeText.time(minute))"
        default: "Calm now"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) {
                    details
                    Spacer(minLength: 12)
                    walkTime(alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: 10) {
                    details
                    walkTime(alignment: .leading)
                }
            }

            RoutePreviewMap(route: result.route, origin: origin, destination: result.destination)
                .frame(height: 110)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))

            if let step = result.route?.firstInstruction {
                Divider().overlay(Color.lowWaterTextSecondary.opacity(0.3))
                HStack(spacing: 14) {
                    Image(systemName: Self.symbol(for: step.instruction))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.lowWaterAccent)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.lowWaterBackground))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.instruction)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.lowWaterText)
                        if step.distance > 0 {
                            Text("then walk \(Walking.distanceText(metres: step.distance))")
                                .font(.footnote)
                                .foregroundStyle(Color.lowWaterTextSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Color.lowWaterCard))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nearest low water")
                .textCase(.uppercase)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.lowWaterAccent)
            Text(result.place.name)
                .font(.title2.bold())
                .foregroundStyle(Color.lowWaterText)
            HStack(spacing: 6) {
                WaveGlyph(count: 1)
                    .stroke(Color.lowWaterAccent, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    .frame(width: 16, height: 10)
                    .accessibilityHidden(true)
                Text(quietLine)
                    .font(.subheadline)
                    .foregroundStyle(Color.lowWaterTextSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func walkTime(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text("\(result.minutes) min")
                .font(.title3.bold())
                .foregroundStyle(Color.lowWaterText)
            Text(Walking.distanceText(metres: result.metres))
                .font(.subheadline)
                .foregroundStyle(Color.lowWaterTextSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(result.minutes) minute walk, \(Walking.distanceText(metres: result.metres))")
    }

    private static func symbol(for instruction: String) -> String {
        let text = instruction.lowercased()
        if text.contains("left") { return "arrow.turn.up.left" }
        if text.contains("right") { return "arrow.turn.up.right" }
        return "arrow.up"
    }
}

/// A small, non-interactive map of the walking route.
struct RoutePreviewMap: View {
    let route: WalkingRoute?
    let origin: GeoPoint
    let destination: GeoPoint

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            if let route {
                MapPolyline(coordinates: route.coordinates)
                    .stroke(Color.lowWaterAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 7]))
            }
            Annotation("You", coordinate: origin.coordinate, anchor: .center) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
            }
            .annotationTitles(.hidden)
            Annotation("Low water", coordinate: destination.coordinate, anchor: .center) {
                Circle()
                    .fill(Color.lowWaterAccent)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().fill(Color.lowWaterBackground).frame(width: 6, height: 6))
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Find low water") {
    LowWaterView()
        .previewEnvironment()
}
