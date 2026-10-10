import MapKit
import SwiftUI

/// Find low water: for someone who is overwhelmed right now. Always dark, gentle and simple.
struct LowWaterView: View {
    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var finder = LowWaterFinder()
    @State private var isShowingCards = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                topBar
                BreathingCircle()
                VStack(spacing: 6) {
                    Text("You're doing fine.")
                        .font(.title2.bold())
                        .foregroundStyle(.lowWaterInk)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.lowWaterInkSecondary)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)

                resultCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            actions
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.lowWaterBackground)
        }
        .background(Color.lowWaterBackground.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .task {
            // Closing a staff card makes this view appear again; keep the place already found.
            guard finder.start == nil else { return }
            findLowWater()
        }
        .onChange(of: finder.announcement) { _, announcement in
            if let announcement {
                AccessibilityNotification.Announcement(announcement).post()
            }
        }
        .fullScreenCover(isPresented: $isShowingCards) {
            StaffCardsView()
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private var topBar: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // At very large text the title gets its own line instead of squeezing between the controls.
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    closeButton
                    Spacer(minLength: 8)
                    dimmedLabel
                }
                title
            }
        } else {
            HStack {
                closeButton
                Spacer()
                title
                Spacer()
                dimmedLabel
            }
        }
    }

    private var closeButton: some View {
        CircleIconButton(systemImage: "xmark", label: "Close", foreground: .lowWaterInk, background: .lowWaterCard) {
            dismiss()
        }
    }

    private var title: some View {
        Text("Low water")
            .font(.headline)
            .foregroundStyle(.lowWaterInk)
            .accessibilityAddTraits(.isHeader)
    }

    private var dimmedLabel: some View {
        Label("Dimmed", systemImage: "moon")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.lowWaterInkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.lowWaterCard, in: Capsule())
            .accessibilityLabel("Dimmed colours")
    }

    private var subtitle: String {
        switch finder.state {
        case .searching:
            "Looking for a calm place nearby."
        case .found(let result):
            result.isCalm ? TideText.calmPlaceAway(minutes: result.minutes) : "Nothing is calm nearby, but this is the quietest place."
        case .nothingOpen:
            "Nothing nearby is open right now. You can still show a card or tell someone."
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        switch finder.state {
        case .searching:
            // A still placeholder: the breathing circle is the screen's only motion.
            Text("Finding the nearest calm place…")
                .font(.subheadline)
                .foregroundStyle(.lowWaterInkSecondary)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(Color.lowWaterCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        case .found(let result):
            LowWaterCard(result: result, start: finder.start)
        case .nothingOpen:
            EmptyView()
        }
    }

    private var foundPlace: LowWaterResult? {
        if case .found(let result) = finder.state {
            return result
        }
        return nil
    }

    private var actions: some View {
        let target = foundPlace
        let secondary = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))

        return VStack(spacing: 10) {
            if let target {
                Button {
                    DirectionsService.openWalkingDirections(to: target.location, name: target.place.name)
                } label: {
                    Text("Start walking")
                        .font(.headline)
                        .foregroundStyle(.lowWaterBackground)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.lowWaterAccent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens walking directions to \(target.place.name) in Maps")
            }

            secondary {
                Button {
                    isShowingCards = true
                } label: {
                    secondaryLabel("Show a card", systemImage: "text.bubble")
                }
                .buttonStyle(.plain)

                ShareLink(item: tellMessage(heading: target?.place.name)) {
                    secondaryLabel(tellTitle, systemImage: "person")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func secondaryLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.lowWaterInk)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.lowWaterCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tellTitle: String {
        profileStore.profile.trustedPersonName.map { "Tell \($0)" } ?? "Tell someone"
    }

    /// A pre-written message with an Apple Maps link to where the user is now.
    private func tellMessage(heading placeName: String?) -> String {
        var message = "I'm feeling overwhelmed, so I'm taking a quiet moment. I'm okay."
        if let placeName {
            message += " I'm heading to \(placeName) to find somewhere calm."
        }
        if let here = locationService.point?.appleMapsURL() {
            message += " I'm here: \(here.absoluteString)"
        }
        return message
    }

    private func findLowWater() {
        let start = locationService.point ?? placeStore.centre ?? .centralLondon
        var locations: [String: GeoPoint] = [:]
        for place in placeStore.places {
            locations[place.id] = placeStore.location(of: place)
        }
        finder.find(
            places: placeStore.places,
            locations: locations,
            engine: profileStore.engine,
            minute: placeStore.minuteOfDay,
            from: start
        )
    }
}

/// "Nearest low water": the place, walking time, a small route map and the first instruction.
private struct LowWaterCard: View {
    let result: LowWaterResult
    let start: GeoPoint?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At very large text the walking time sits under the name instead of beside it.
        let header = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        VStack(alignment: .leading, spacing: 14) {
            header {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.isCalm ? "Nearest low water" : "Quietest nearby")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.lowWaterAccent)
                    Text(result.place.name)
                        .font(.title3.bold())
                        .foregroundStyle(.lowWaterInk)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if result.isCalm {
                            StatusGlyph(status: .calm, color: .lowWaterAccent)
                        }
                        Text(result.statusText)
                            .font(.subheadline)
                            .foregroundStyle(.lowWaterInkSecondary)
                    }
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                    Text("\(result.minutes) min")
                        .font(.title3.bold())
                        .foregroundStyle(.lowWaterInk)
                    Text(TideText.distance(metres: result.metres))
                        .font(.footnote)
                        .foregroundStyle(.lowWaterInkSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            RoutePreview(route: result.route, start: start, destination: result.location)
                // The map's initial framing is fixed, so rebuild it when the real route arrives.
                .id(result.route == nil ? "line" : "route")
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let instruction = result.instruction {
                Rectangle()
                    .fill(Color.lowWaterInkSecondary.opacity(0.25))
                    .frame(height: 1)
                    .accessibilityHidden(true)
                HStack(spacing: 12) {
                    Image(systemName: Self.turnSymbol(for: instruction))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.lowWaterAccent)
                        .frame(width: 40, height: 40)
                        .background(Color.lowWaterBackground, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instruction)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.lowWaterInk)
                        if let detail = result.instructionDetail {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.lowWaterInkSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background(Color.lowWaterCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    static func turnSymbol(for instruction: String) -> String {
        let text = instruction.lowercased()
        if text.contains("left") { return "arrow.turn.up.left" }
        if text.contains("right") { return "arrow.turn.up.right" }
        return "arrow.up"
    }
}

/// A small, non-interactive map with the walking route. Decorative: the card text says it all.
private struct RoutePreview: View {
    let route: MKRoute?
    let start: GeoPoint?
    let destination: GeoPoint

    var body: some View {
        Map(initialPosition: .rect(visibleRect), interactionModes: []) {
            if let route {
                MapPolyline(route)
                    .stroke(Color.lowWaterAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [1, 8]))
            } else if let start {
                MapPolyline(coordinates: [start.coordinate, destination.coordinate])
                    .stroke(Color.lowWaterAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [1, 8]))
            }
            if let start {
                Annotation("You", coordinate: start.coordinate) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                .annotationTitles(.hidden)
            }
            Annotation("Low water", coordinate: destination.coordinate) {
                Circle()
                    .fill(Color.lowWaterAccent)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().fill(Color.lowWaterBackground).frame(width: 6, height: 6))
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var visibleRect: MKMapRect {
        if let route {
            return route.polyline.boundingMapRect.padded(by: 0.35)
        }
        let points = [destination, start ?? destination].map { MKMapPoint($0.coordinate) }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let rect = MKMapRect(
            x: xs.min() ?? 0,
            y: ys.min() ?? 0,
            width: (xs.max() ?? 0) - (xs.min() ?? 0),
            height: (ys.max() ?? 0) - (ys.min() ?? 0)
        )
        return rect.padded(by: 0.35)
    }
}

#Preview("Find low water") {
    Color.ground
        .fullScreenCover(isPresented: .constant(true)) {
            LowWaterView()
        }
        .previewEnvironment()
}

#Preview("Find low water, largest text") {
    Color.ground
        .fullScreenCover(isPresented: .constant(true)) {
            LowWaterView()
        }
        .previewEnvironment()
        .dynamicTypeSize(.accessibility3)
}
