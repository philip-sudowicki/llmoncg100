import MapKit
import SwiftUI

/// The root screen: our places on Apple Maps, coloured for the user, under a persistent sheet.
struct MapScreen: View {
    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(LocationService.self) private var locationService
    @Environment(MapModel.self) private var mapModel

    var body: some View {
        @Bindable var mapModel = mapModel
        let engine = profileStore.engine
        let minute = placeStore.minuteOfDay
        let pins = placeStore.places.filter(mapModel.filter.showsPin)

        Map(position: $mapModel.position, selection: $mapModel.selectedPlaceID) {
            UserAnnotation()

            ForEach(pins) { place in
                let status = engine.status(of: place, at: minute)
                let spoken = TideText.spokenStatus(status, change: engine.nextChange(for: place, at: minute), now: minute)
                Annotation(place.name, coordinate: placeStore.location(of: place).coordinate, anchor: .center) {
                    PlacePin(name: place.name, status: status, isSelected: mapModel.selectedPlaceID == place.id) {
                        mapModel.showDetail(for: place.id)
                    }
                    .accessibilityLabel("\(place.name), \(spoken)")
                    // Applied here so the pin's scaled badge is capped too, not only its text.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                }
                .annotationTitles(.hidden)
                .tag(place.id)
            }

            if let route = mapModel.route {
                MapPolyline(route)
                    .stroke(Color.calmDeep, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .safeAreaInset(edge: .top) {
            MapTopOverlay()
        }
        // Keep pins, controls and camera framing clear of the sheet at its lowest height.
        .safeAreaPadding(.bottom, 300)
        .onChange(of: mapModel.selectedPlaceID) { _, placeID in
            if let placeID {
                mapModel.showDetail(for: placeID)
            }
        }
        .onChange(of: locationService.point) { _, point in
            // A fix that arrives after the fallback (slow GPS, or permission granted later in
            // Settings) moves the places around the user once.
            if let point, placeStore.isFallbackCentre {
                placeStore.anchor(at: point)
            }
        }
        .onChange(of: placeStore.centre, initial: true) { old, centre in
            if old != nil {
                // The places moved, so any route drawn to their old positions is wrong.
                mapModel.clearRoute()
            }
            if let centre {
                mapModel.focus(on: centre)
            }
        }
        .task {
            locationService.start()
            await anchorPlaces()
        }
        .sheet(isPresented: .constant(true)) {
            NearbySheet()
        }
    }

    /// Lays the sample places around the user's first location fix, or central London when
    /// location is denied or slow to arrive.
    private func anchorPlaces() async {
        var waited = Duration.zero
        // Counted only once permission is granted, so time spent reading the prompt doesn't count.
        var waitedForFix = Duration.zero
        let step = Duration.milliseconds(250)
        while placeStore.centre == nil, !Task.isCancelled {
            if let point = locationService.precisePoint {
                placeStore.anchor(at: point)
            } else if waitedForFix >= .seconds(8), let rough = locationService.point {
                // No precise fix in time: the best one so far is still better than London.
                placeStore.anchor(at: rough)
            } else if locationService.isUnavailable
                        || waitedForFix >= .seconds(8)
                        || waited >= .seconds(60) {
                placeStore.anchor(at: .centralLondon, isFallback: true)
            } else {
                try? await Task.sleep(for: step)
                waited += step
                if locationService.isAuthorized {
                    waitedForFix += step
                }
            }
        }
    }
}

#Preview("Map") {
    MapScreen()
        .previewEnvironment()
}

#Preview("Map, dark") {
    MapScreen()
        .previewEnvironment()
        .preferredColorScheme(.dark)
}
