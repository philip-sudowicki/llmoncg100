import MapKit
import Observation
import SwiftUI

/// A place page pushed inside the bottom sheet.
struct PlaceRoute: Hashable {
    let placeID: String
}

/// UI state shared by the map and its bottom sheet: camera, selection, sheet height, route and
/// which screen is presented. Presentations hang off the sheet, because the map is already
/// presenting the sheet itself.
@MainActor
@Observable
final class MapModel {
    static let peekDetent = PresentationDetent.height(320)

    var position: MapCameraPosition = .userLocation(fallback: .automatic)
    var selectedPlaceID: String?
    var path: [PlaceRoute] = []
    var detent: PresentationDetent = MapModel.peekDetent
    var filter = MapFilter()

    private(set) var route: MKRoute?
    private(set) var routePlaceID: String?

    var isShowingProfile = false
    var isShowingLowWater = false
    var checkInPlace: Place?

    /// Shows a place's details in the sheet and raises it.
    func showDetail(for placeID: String) {
        if routePlaceID != nil, routePlaceID != placeID {
            clearRoute()
        }
        selectedPlaceID = placeID
        if path.last?.placeID != placeID {
            path = [PlaceRoute(placeID: placeID)]
        }
        detent = .large
    }

    func closeDetail() {
        clearRoute()
        path = []
        selectedPlaceID = nil
        detent = Self.peekDetent
    }

    /// Keeps selection in step when the sheet's navigation pops.
    func pathChanged() {
        if path.isEmpty {
            // A pop by any means (for example the VoiceOver escape gesture) cleans up like Close.
            selectedPlaceID = nil
            clearRoute()
            if detent == .large {
                detent = Self.peekDetent
            }
        }
    }

    func focus(on centre: GeoPoint) {
        position = .region(MKCoordinateRegion(center: centre.coordinate, latitudinalMeters: 700, longitudinalMeters: 700))
    }

    /// Draws a walking route and lowers the sheet so the route is visible.
    func show(_ route: MKRoute, to placeID: String) {
        self.route = route
        routePlaceID = placeID
        detent = Self.peekDetent
        position = .rect(route.polyline.boundingMapRect.padded(by: 0.3))
    }

    func clearRoute() {
        route = nil
        routePlaceID = nil
    }
}
