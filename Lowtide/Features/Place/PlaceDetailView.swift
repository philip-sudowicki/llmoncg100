import SwiftUI

/// A place's page inside the bottom sheet.
struct PlaceDetailView: View {
    let placeID: String

    @Environment(PlaceStore.self) private var placeStore
    @Environment(MapModel.self) private var mapModel

    var body: some View {
        if let place = placeStore.place(id: placeID) {
            PlaceDetailContent(place: place)
        } else {
            ContentUnavailableView("Place not found", systemImage: "mappin.slash")
                .overlay(alignment: .topTrailing) {
                    CircleIconButton(systemImage: "xmark", label: "Close") {
                        mapModel.closeDetail()
                    }
                    .padding(20)
                }
        }
    }
}

private struct PlaceDetailContent: View {
    let place: Place

    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(PersonalStore.self) private var personalStore
    @Environment(LocationService.self) private var locationService
    @Environment(MapModel.self) private var mapModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isRouting = false
    @State private var isAlertScheduled = false
    @State private var actionMessage: String?
    @State private var isShowingAlertsOff = false

    var body: some View {
        let engine = profileStore.engine
        let minute = placeStore.minuteOfDay
        let status = engine.status(of: place, at: minute)
        let change = engine.nextChange(for: place, at: minute)
        let location = placeStore.location(of: place)
        let reference = locationService.point ?? placeStore.centre ?? .centralLondon
        let walk = Walking.minutes(forStraightLineMetres: reference.distance(to: location))

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(walk: walk, minute: minute)
                StatusBanner(status: status, banner: TideText.banner(status: status, change: change, now: minute, place: place))
                actions(engine: engine, minute: minute, status: status, change: change, location: location)

                if let actionMessage {
                    Text(actionMessage)
                        .font(.subheadline)
                        .foregroundStyle(.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                sectionTitle("Today's tide", trailing: "\(placeStore.now.formatted(.dateTime.weekday(.wide))) · for you")
                TideChartCard(place: place, engine: engine, minute: minute)

                HStack(alignment: .center) {
                    sectionTitle("How it feels")
                    Spacer(minLength: 8)
                    if engine.isGoodMatch(place, at: minute) {
                        Pill(text: "Good match for you")
                    }
                }
                HowItFeelsCard(place: place, engine: engine, minute: minute)

                if !GoodToKnowCard.lines(for: place).isEmpty {
                    sectionTitle("Good to know")
                    GoodToKnowCard(place: place)
                }

                if let checkIn = personalStore.latestCheckIns[place.id] {
                    HStack(spacing: 8) {
                        StatusGlyph(status: checkIn.feeling.status)
                        Text(TideText.checkIn(checkIn.feeling, at: checkIn.date, today: placeStore.now))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.ink)
                    }
                    .accessibilityElement(children: .combine)
                }

                Button {
                    mapModel.checkInPlace = place
                } label: {
                    Label("How's the tide?", systemImage: "plus.circle")
                }
                .buttonStyle(.outlined)

                Text("Forecasts in this version are sample data, the same every day.")
                    .font(.footnote)
                    .foregroundStyle(.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(Color.surface)
        // Rechecked every minute so 'Alert set' clears once the alert has fired.
        .task(id: "\(place.id).\(profileStore.profile.gentleAlerts).\(minute)") {
            isAlertScheduled = await NotificationService.scheduledPlaceIDs().contains(place.id)
        }
        .alert("Gentle alerts are off", isPresented: $isShowingAlertsOff) {
            Button("Turn on and set alert") {
                profileStore.setGentleAlerts(true)
                Task { await setAlert(engine: engine, minute: minute, status: status) }
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Alert me uses gentle alerts, which are off in your Tide profile. They are silent and only arrive when you ask.")
        }
    }

    // MARK: Header

    private func header(walk: Int, minute: Int) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return layout {
            if dynamicTypeSize.isAccessibilitySize {
                closeButton
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.title2.bold())
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("\(place.category.title) · \(place.street) · \(TideText.walk(minutes: walk))")
                    .font(.subheadline)
                    .foregroundStyle(.inkSecondary)
                Text(TideText.openingLine(for: place, now: minute))
                    .font(.subheadline)
                    .foregroundStyle(.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // VoiceOver reads the place name first even when Close sits above it.
            .accessibilitySortPriority(1)
            if !dynamicTypeSize.isAccessibilitySize {
                closeButton
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var closeButton: some View {
        CircleIconButton(systemImage: "xmark", label: "Close") {
            mapModel.closeDetail()
        }
    }

    private func sectionTitle(_ title: String, trailing: String? = nil) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(.footnote)
                        .foregroundStyle(.inkSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                if let trailing {
                    Text(trailing)
                        .font(.footnote)
                        .foregroundStyle(.inkSecondary)
                }
            }
        }
    }

    // MARK: Actions

    private func actions(engine: TideEngine, minute: Int, status: TideStatus?, change: TideChange, location: GeoPoint) -> some View {
        // Four across at standard sizes; fewer as text grows, so "Directions" never breaks mid-word.
        let count = dynamicTypeSize >= .accessibility2 ? 1 : (dynamicTypeSize >= .xLarge ? 2 : 4)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
        let isRouteShown = mapModel.routePlaceID == place.id
        let isSaved = personalStore.isSaved(place.id)
        // Gentle alerts is the master switch: with it off, no alert counts as set.
        let isAlertOn = isAlertScheduled && profileStore.profile.gentleAlerts

        return LazyVGrid(columns: columns, spacing: 8) {
            ActionTile(
                title: isRouting ? "Finding…" : (isRouteShown ? "Hide route" : "Directions"),
                systemImage: "arrow.triangle.turn.up.right.diamond",
                isProminent: true,
                isOn: isRouteShown
            ) {
                if isRouteShown {
                    mapModel.clearRoute()
                    announce("Route hidden.")
                } else {
                    Task { await showDirections(to: location) }
                }
            }
            .disabled(isRouting)

            ActionTile(
                title: isAlertOn ? "Alert set" : "Alert me",
                systemImage: isAlertOn ? "bell.fill" : "bell",
                isOn: isAlertOn
            ) {
                if isAlertOn {
                    NotificationService.cancelCalmAlert(placeID: place.id)
                    isAlertScheduled = false
                    announce("Alert cancelled.")
                } else if !profileStore.profile.gentleAlerts {
                    isShowingAlertsOff = true
                } else {
                    Task { await setAlert(engine: engine, minute: minute, status: status) }
                }
            }

            ActionTile(
                title: isSaved ? "Saved" : "Save",
                systemImage: isSaved ? "bookmark.fill" : "bookmark",
                isOn: isSaved
            ) {
                personalStore.toggleSaved(place.id)
            }

            ShareLink(
                item: location.appleMapsURL(name: place.name) ?? URL(string: "https://maps.apple.com")!,
                subject: Text(place.name),
                message: Text("\(place.name), \(place.street). \(TideText.nextChange(change, now: minute)) for me, on Lowtide.")
            ) {
                ActionTileLabel(title: "Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        }
    }

    private func showDirections(to destination: GeoPoint) async {
        let start = locationService.point ?? placeStore.centre ?? .centralLondon
        isRouting = true
        defer { isRouting = false }
        do {
            let route = try await DirectionsService.walkingRoute(from: start, to: destination)
            // The user may have closed this page, opened another place, or the places may have moved
            // to a new location fix while the route loaded.
            guard mapModel.path.last?.placeID == place.id, placeStore.location(of: place) == destination else { return }
            mapModel.show(route, to: place.id)
            announce("Walking route shown on the map. About \(max(1, Int((route.expectedTravelTime / 60).rounded()))) minutes.")
        } catch {
            announce("Walking directions aren't available right now.")
        }
    }

    /// Schedules a silent notification for the start of the next calm window today.
    private func setAlert(engine: TideEngine, minute: Int, status: TideStatus?) async {
        guard let window = engine.nextCalmWindow(for: place, after: minute) else {
            if status == .calm {
                announce("It's calm there now, and there's no other calm spell later today.")
            } else {
                announce("There's no calm spell left there today.")
            }
            return
        }
        // Round up to the next five minutes so the alert never arrives before it turns calm.
        let start = min(((window.start + 4) / 5) * 5, window.end - 1)
        let until = window.end == place.hours.closes
            ? "until it closes at \(TideText.clock(window.end))"
            : "until about \(TideText.clock(TideText.displayMinute(window.end, now: minute)))"
        let result = await NotificationService.scheduleCalmAlert(
            placeID: place.id,
            title: "Low tide at \(place.name)",
            body: "It should be calm for you now, \(until).",
            at: placeStore.clock.realDate(forMinute: start)
        )
        switch result {
        case .scheduled:
            isAlertScheduled = true
            announce("We'll let you know at \(TideText.clock(start)), when it should turn calm.")
        case .permissionDenied:
            announce("Notifications are off for Lowtide. You can turn them on in Settings.")
        case .failed:
            announce("The alert couldn't be set. Please try again.")
        }
    }

    /// Shows a short confirmation under the buttons and reads it out for VoiceOver users.
    private func announce(_ message: String) {
        actionMessage = message
        AccessibilityNotification.Announcement(message).post()
    }
}

/// The status banner, tinted for the status, with its glyph so it never relies on colour alone.
struct StatusBanner: View {
    let status: TideStatus?
    let banner: (title: String, detail: String)

    @ScaledMetric(relativeTo: .headline) private var badgeSize: CGFloat = 40

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            StatusBadge(status: status, size: min(badgeSize, 56))
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.headline)
                    .foregroundStyle(.ink)
                Text(banner.detail)
                    .font(.subheadline)
                    .foregroundStyle(.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(status?.tint ?? Color.ground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Place page") {
    PlaceDetailView(placeID: "marlow-street-library")
        .previewEnvironment()
}

#Preview("Place page, high tide") {
    PlaceDetailView(placeID: "northgate-market")
        .previewEnvironment()
}

#Preview("Place page, dark") {
    PlaceDetailView(placeID: "marlow-street-library")
        .previewEnvironment()
        .preferredColorScheme(.dark)
}

#Preview("Place page, largest text") {
    PlaceDetailView(placeID: "larkspur-gardens")
        .previewEnvironment()
        .dynamicTypeSize(.accessibility3)
}
