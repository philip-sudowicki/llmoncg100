import SwiftData
import SwiftUI
import UIKit

/// A place's page, shown inside the map's sheet.
struct PlaceDetailView: View {
    let placeID: String
    @Environment(PlaceStore.self) private var placeStore

    var body: some View {
        if let place = placeStore.place(id: placeID) {
            PlaceDetailContent(place: place)
        } else {
            ContentUnavailableView("Place not found", systemImage: "mappin.slash")
        }
    }
}

private struct PlaceDetailContent: View {
    let place: Place

    @Environment(MapModel.self) private var model
    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(LocationService.self) private var location
    @Environment(TideClock.self) private var clock
    @Environment(NotificationService.self) private var notifications
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query private var saved: [SavedPlace]
    @Query private var checkIns: [CheckIn]
    @State private var prompt: AlertPrompt?

    init(place: Place) {
        self.place = place
        let id = place.id
        _saved = Query(filter: #Predicate<SavedPlace> { $0.placeID == id })
        _checkIns = Query(filter: #Predicate<CheckIn> { $0.placeID == id }, sort: \CheckIn.date, order: .reverse)
    }

    private var engine: TideEngine { TideEngine(profile: profileStore.profile) }
    private var narrative: TideNarrative { TideNarrative(engine: engine) }
    private var minute: Int { clock.minuteOfDay }
    private var status: TideStatus? { engine.status(of: place, atMinute: minute) }
    private var position: GeoPoint? { placeStore.position(of: place) }
    private var isSaved: Bool { !saved.isEmpty }
    private var alertMinute: Int? { notifications.scheduled[place.id] }
    private var hasRoute: Bool { model.routePlaceID == place.id && model.route != nil }

    private var subtitle: String {
        var parts = [place.category.title, place.street]
        if let position, let origin = location.current ?? placeStore.anchor {
            parts.append("\(Walking.estimatedMinutes(straightLineMetres: origin.distance(to: position))) min walk")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                StatusBanner(
                    status: status,
                    title: narrative.bannerTitle(for: status),
                    detail: narrative.bannerDetail(for: place, atMinute: minute)
                )
                actions
                TideChartCard(place: place, engine: engine, minute: minute, weekday: clock.weekday)
                HowItFeelsCard(place: place, engine: engine, minute: minute)
                GoodToKnowCard(place: place)
                checkInSection
                Text("This is a sample forecast. In this version every day follows the same pattern.")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityAction(.escape) { model.closePlace() }
        .alert(
            prompt?.title ?? "",
            isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } }),
            presenting: prompt
        ) { prompt in
            switch prompt {
            case .turnOnGentleAlerts:
                Button("Turn on") {
                    profileStore.profile.gentleAlerts = true
                    profileStore.save()
                    Task { await scheduleAlert() }
                }
                Button("Not now", role: .cancel) {}
            case .notificationsOff:
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("OK", role: .cancel) {}
            case .noCalmLeft, .failed:
                Button("OK", role: .cancel) {}
            }
        } message: { prompt in
            Text(prompt.message(placeName: place.name))
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.title.bold())
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                Text(narrative.hoursLine(for: place, atMinute: minute))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                model.closePlace()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: Metrics.minimumTapTarget, height: Metrics.minimumTapTarget)
                    .background(Circle().fill(Color.ground))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Button {
                    toggleRoute()
                } label: {
                    ActionLabel(
                        title: hasRoute ? "Hide route" : (model.isFindingRoute ? "Finding…" : "Directions"),
                        systemImage: "arrow.triangle.turn.up.right.diamond"
                    )
                }
                .buttonStyle(ActionButtonStyle(isProminent: true))
                .disabled(model.isFindingRoute || position == nil)
                .accessibilityHint("Draws a walking route on the map")

                Button {
                    alertTapped()
                } label: {
                    ActionLabel(title: alertMinute == nil ? "Alert me" : "Alert set", systemImage: alertMinute == nil ? "bell" : "bell.fill")
                }
                .buttonStyle(ActionButtonStyle())
                .accessibilityHint(alertMinute == nil ? "Sends a quiet notification when it's calm" : "Cancels the alert")

                Button {
                    toggleSaved()
                } label: {
                    ActionLabel(title: isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(ActionButtonStyle())
                .accessibilityAddTraits(isSaved ? .isSelected : [])

                shareButton
            }

            if let alertMinute {
                Label("We'll send a quiet alert at \(TimeText.time(alertMinute)). Tap Alert set to cancel it.", systemImage: "bell")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
            }
            if let error = model.routeError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        let message = "\(place.name): \(narrative.statusLine(for: place, atMinute: minute).lowercasedFirst). Found with Lowtide."
        if let url = mapsURL {
            ShareLink(item: url, subject: Text(place.name), message: Text(message)) {
                ActionLabel(title: "Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(ActionButtonStyle())
        } else {
            ShareLink(item: message) {
                ActionLabel(title: "Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(ActionButtonStyle())
        }
    }

    private var mapsURL: URL? {
        guard let position else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(position.latitude),\(position.longitude)"),
            URLQueryItem(name: "q", value: place.name),
        ]
        return components?.url
    }

    private func toggleRoute() {
        if hasRoute {
            model.clearRoute()
            return
        }
        guard let destination = position, let origin = location.current ?? placeStore.anchor else { return }
        Task { await model.findRoute(from: origin, to: destination, placeID: place.id) }
    }

    private func toggleSaved() {
        if let existing = saved.first {
            modelContext.delete(existing)
        } else {
            modelContext.insert(SavedPlace(placeID: place.id))
        }
        try? modelContext.save()
    }

    private func alertTapped() {
        if alertMinute != nil {
            notifications.cancel(placeID: place.id)
        } else if !profileStore.profile.gentleAlerts {
            prompt = .turnOnGentleAlerts
        } else {
            Task { await scheduleAlert() }
        }
    }

    private func scheduleAlert() async {
        guard let start = engine.nextCalmStart(for: place, atMinute: minute) else {
            prompt = .noCalmLeft
            return
        }
        switch await notifications.schedule(placeID: place.id, placeName: place.name, atMinute: start) {
        case .scheduled:
            break
        case .notAllowed:
            prompt = .notificationsOff
        case .failed:
            prompt = .failed
        }
    }

    // MARK: Check-in

    private var checkInSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                model.checkInPlace = place
            } label: {
                Label("How's the tide?", systemImage: "plus.circle")
            }
            .buttonStyle(OutlinedButtonStyle())
            .accessibilityHint("Tell Lowtide how it feels here right now")

            if let latest = checkIns.first {
                HStack(spacing: 8) {
                    StatusBadge(status: latest.checkInFeeling.status, size: 18)
                    Text("You checked in: \(latest.checkInFeeling.title) · \(Self.checkInTime(latest.date))")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private static func checkInTime(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

/// Reasons "Alert me" needs to say something.
private enum AlertPrompt: Identifiable {
    case turnOnGentleAlerts
    case noCalmLeft
    case notificationsOff
    case failed

    var id: Self { self }

    var title: String {
        switch self {
        case .turnOnGentleAlerts: "Gentle alerts are off"
        case .noCalmLeft: "No calm time left today"
        case .notificationsOff: "Notifications are off"
        case .failed: "Couldn't set the alert"
        }
    }

    func message(placeName: String) -> String {
        switch self {
        case .turnOnGentleAlerts:
            "Turn on gentle alerts to get one quiet notification when \(placeName) is calm. You can change this in your Tide profile."
        case .noCalmLeft:
            "There's no other calm time at \(placeName) before it closes today."
        case .notificationsOff:
            "Lowtide isn't allowed to send notifications. You can allow them in Settings."
        case .failed:
            "Something went wrong. Please try again."
        }
    }
}

/// "Low tide now / Calm until about 3:30pm, then the after-school rush."
struct StatusBanner: View {
    let status: TideStatus?
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let status {
                StatusBadge(status: status, size: 40)
            } else {
                ClosedBadge(size: 40)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
            }
            .foregroundStyle(status?.tintText ?? Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous)
                .fill(status?.tint ?? Color.ground)
        )
        .accessibilityElement(children: .combine)
    }
}

/// "How it feels": noise, light, crowds and smells right now, plus heads-up triggers.
struct HowItFeelsCard: View {
    let place: Place
    let engine: TideEngine
    let minute: Int

    /// While closed, show what to expect at opening time.
    private var sampleMinute: Int {
        place.hours.isOpen(atMinute: minute) ? minute : place.hours.open
    }

    var body: some View {
        let values = place.forecast.values(atMinute: Double(sampleMinute))
        let decibels = place.forecast.decibels(atMinute: Double(sampleMinute))
        let headsUp = engine.headsUp(for: place)

        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "How it feels") {
                if engine.isGoodMatch(place, atMinute: minute) {
                    Text("Good match for you")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.calmDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.calmTint))
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                if !place.hours.isOpen(atMinute: minute) {
                    Text("Closed now. This is what to expect when it opens at \(TimeText.time(place.hours.open)).")
                        .font(.footnote)
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.bottom, 8)
                }
                FeelRow(
                    symbol: "speaker.wave.1", title: "Noise",
                    detail: place.notes.noise.map { "\($0) · \(SoundLevel.approximate(decibels))" }
                        ?? "\(SoundLevel.feel(forDecibels: decibels)) · \(SoundLevel.approximate(decibels))",
                    steps: FeelText.meterSteps(values.noise)
                )
                Divider()
                FeelRow(
                    symbol: "sun.max", title: "Light",
                    detail: place.notes.light ?? FeelText.light(values.light),
                    steps: FeelText.meterSteps(values.light)
                )
                Divider()
                FeelRow(
                    symbol: "person.2", title: "Crowds",
                    detail: place.notes.crowd ?? FeelText.crowd(values.crowd),
                    steps: FeelText.meterSteps(values.crowd)
                )
                Divider()
                FeelRow(
                    symbol: "nose", title: "Smells",
                    detail: place.notes.smell ?? FeelText.smell(values.smell),
                    steps: FeelText.meterSteps(values.smell)
                )

                if !headsUp.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Heads-up for your profile")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .accessibilityAddTraits(.isHeader)
                        FlowLayout {
                            ForEach(headsUp) { HeadsUpChip(text: $0.text) }
                        }
                    }
                    .padding(.top, 14)
                }
            }
            .card()
        }
    }
}

private struct FeelRow: View {
    let symbol: String
    let title: String
    let detail: String
    let steps: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(Color.calmDeep)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            StepMeter(filled: steps)
                .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(detail). Level \(steps) of 5")
    }
}

/// "Good to know": practical notes, including any regular quiet hour.
struct GoodToKnowCard: View {
    let place: Place

    private var items: [(symbol: String, text: String)] {
        var items: [(symbol: String, text: String)] = []
        if let quiet = place.quietHour {
            items.append((symbol: "clock", text: "Quiet hour on \(quiet.days), \(TimeText.range(from: quiet.start, to: quiet.end))"))
        }
        items += place.goodToKnow.map { (symbol: $0.kind.symbol, text: $0.text) }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading("Good to know")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider() }
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Image(systemName: item.symbol)
                            .foregroundStyle(Color.calmDeep)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(item.text)
                            .font(.body)
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 12)
                }
            }
            .card(padding: 16)
        }
    }
}

extension GoodToKnow.Kind {
    var symbol: String {
        switch self {
        case .quietSpace: "door.left.hand.closed"
        case .quietHour: "clock"
        case .staff: "heart"
        case .stepFree: "figure.roll"
        case .seating: "chair"
        case .toilets: "toilet"
        case .outdoors: "tree"
        case .lighting: "lightbulb"
        case .kit: "headphones"
        case .info: "info.circle"
        }
    }
}

#Preview("Place page") {
    NavigationStack {
        PlaceDetailView(placeID: "marlow-street-library")
    }
    .previewEnvironment()
}

#Preview("Place page, closed") {
    NavigationStack {
        PlaceDetailView(placeID: "harbour-tea-room")
    }
    .previewEnvironment(minute: 20 * 60)
}
