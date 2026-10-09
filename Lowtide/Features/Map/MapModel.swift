import MapKit
import Observation
import SwiftUI

/// State for the map, its persistent sheet and everything presented from it.
@MainActor
@Observable
final class MapModel {
    /// The sheet's resting height, like Apple Maps.
    static var peekDetent: PresentationDetent { .height(320) }

    var camera: MapCameraPosition = .automatic
    var selectedPlaceID: String?
    /// The sheet's navigation path: place IDs.
    var path: [String] = []
    var detent: PresentationDetent = .height(320)
    var filter = PlaceFilter()

    var route: WalkingRoute?
    var routePlaceID: String?
    var isFindingRoute = false
    var routeError: String?

    var checkInPlace: Place?
    var isShowingProfile = false
    var isShowingLowWater = false

    func showPlace(_ id: String) {
        if path != [id] { path = [id] }
        selectedPlaceID = id
        detent = .large
    }

    func closePlace() {
        path = []
        selectedPlaceID = nil
        clearRoute()
        detent = Self.peekDetent
    }

    /// Frames the demo centre, nudged so places sit above the sheet.
    func focus(on anchor: GeoPoint) {
        let centre = anchor.offsetBy(east: 0, north: -230)
        camera = .region(MKCoordinateRegion(center: centre.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500))
    }

    func showRoute(_ route: WalkingRoute, to placeID: String) {
        self.route = route
        routePlaceID = placeID
        routeError = nil
        detent = Self.peekDetent
        if let region = DirectionsService.region(fitting: route.points) {
            camera = .region(region)
        }
    }

    func clearRoute() {
        route = nil
        routePlaceID = nil
        routeError = nil
    }

    func findRoute(from origin: GeoPoint, to destination: GeoPoint, placeID: String) async {
        isFindingRoute = true
        routeError = nil
        defer { isFindingRoute = false }
        do {
            let route = try await DirectionsService.walkingRoute(from: origin, to: destination)
            showRoute(route, to: placeID)
        } catch {
            routeError = "Walking directions aren't available right now. Check your connection and try again."
        }
    }
}
