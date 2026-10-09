import MapKit
import SwiftUI

/// The root screen: a full-screen map of places coloured for the user, with a persistent sheet.
struct MapScreen: View {
    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(LocationService.self) private var location
    @Environment(TideClock.self) private var clock
    @Environment(NotificationService.self) private var notifications
    @State private var model = MapModel()

    private var engine: TideEngine { TideEngine(profile: profileStore.profile) }

    private var pins: [PlaceSummary] {
        guard let anchor = placeStore.anchor else { return [] }
        return PlaceSummary.make(
            model.filter.mapPlaces(placeStore.places),
            engine: engine,
            minute: clock.minuteOfDay,
            anchor: anchor,
            origin: location.current ?? anchor
        )
    }

    var body: some View {
        @Bindable var model = model
        Map(position: $model.camera, selection: $model.selectedPlaceID) {
            UserAnnotation()

            ForEach(pins) { pin in
                Annotation(pin.place.name, coordinate: pin.position.coordinate, anchor: .center) {
                    PlacePin(summary: pin, isSelected: model.selectedPlaceID == pin.id)
                }
                .annotationTitles(.hidden)
                .tag(pin.id)
            }

            if let route = model.route {
                MapPolyline(coordinates: route.coordinates)
                    .stroke(Color.calmDeep, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .safeAreaInset(edge: .top) {
            MapOverlay(model: model)
        }
        .sheet(isPresented: .constant(true)) {
            NearbySheet()
                .environment(model)
                .presentationDetents([MapModel.peekDetent, .medium, .large], selection: $model.detent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationBackground(Color.surface)
                .presentationCornerRadius(Metrics.sheetRadius)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
        .onChange(of: model.selectedPlaceID) { _, id in
            if let id { model.showPlace(id) }
        }
        .onChange(of: model.path) { _, path in
            if path.isEmpty { model.selectedPlaceID = nil }
        }
        .onChange(of: location.current) { _, fix in
            // If we fell back to London while waiting for a fix, move the demo to the user.
            guard let fix, placeStore.anchorIsFallback, location.isAuthorized else { return }
            placeStore.setAnchor(fix, isFallback: false)
            model.focus(on: fix)
        }
        .task {
            await placeStore.loadIfNeeded()
            await notifications.refresh()
            await resolveAnchor()
            await openDemoScreen()
        }
    }

    /// Waits for the first location fix to place the sample data, falling back to central London.
    private func resolveAnchor() async {
        if let anchor = placeStore.anchor {
            model.focus(on: anchor)
            return
        }
        location.start()
        var waited = 0.0
        while placeStore.anchor == nil, !Task.isCancelled {
            if let fix = location.current {
                placeStore.setAnchor(fix, isFallback: false)
            } else if location.isDenied
                        || (location.isAuthorized && waited >= 8)
                        || waited >= 30 {
                placeStore.setAnchor(.londonFallback, isFallback: true)
            } else {
                try? await Task.sleep(for: .milliseconds(250))
                waited += 0.25
            }
        }
        if let anchor = placeStore.anchor { model.focus(on: anchor) }
    }

    private func openDemoScreen() async {
        guard let screen = DemoOptions.screen else { return }
        try? await Task.sleep(for: .seconds(1))
        switch screen {
        case .place(let id):
            model.showPlace(id)
        case .route(let id):
            model.showPlace(id)
            if let place = placeStore.place(id: id), let destination = placeStore.position(of: place),
               let origin = location.current ?? placeStore.anchor {
                await model.findRoute(from: origin, to: destination, placeID: id)
            }
        case .checkIn(let id):
            model.checkInPlace = placeStore.place(id: id)
        case .lowWater, .cards:
            model.isShowingLowWater = true
        case .profile:
            model.isShowingProfile = true
        case .map, .onboarding:
            break
        }
    }
}

/// A white capsule with the status badge and the place's name.
struct PlacePin: View {
    let summary: PlaceSummary
    var isSelected = false

    var body: some View {
        HStack(spacing: 6) {
            if let status = summary.status {
                StatusBadge(status: status)
            } else {
                ClosedBadge()
            }
            Text(summary.place.name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(summary.status == nil ? Color.inkSecondary : Color.ink)
                .fixedSize()
        }
        .padding(.leading, 5)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.surface))
        .overlay(
            Capsule().strokeBorder(isSelected ? Color.calmDeep : Color.divider, lineWidth: isSelected ? 2 : 0.5)
        )
        .shadow(color: .black.opacity(0.14), radius: 6, y: 2)
        .frame(minHeight: Metrics.minimumTapTarget)
        .contentShape(Rectangle())
        // Map labels stay compact; the sheet's list reflows fully at every text size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.place.name), \(summary.spokenStatus)")
        .accessibilityHint("Shows details")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Map") {
    MapScreen()
        .previewEnvironment()
}

#Preview("Pins") {
    let summaries = PlaceSummary.make(
        PreviewData.places,
        engine: TideEngine(profile: .standard),
        minute: PreviewData.minute,
        anchor: PreviewData.anchor,
        origin: PreviewData.anchor
    )
    return VStack(alignment: .leading, spacing: 8) {
        ForEach(summaries) { PlacePin(summary: $0) }
    }
    .padding()
    .background(Color.ground)
}
