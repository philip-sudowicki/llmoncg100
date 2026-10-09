import CoreLocation
import Foundation
import MapKit

extension GeoPoint {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// An Apple Maps link to this point, for sharing.
    func appleMapsURL(name: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        var items = [URLQueryItem(name: "ll", value: String(format: "%.6f,%.6f", latitude, longitude))]
        if let name {
            items.append(URLQueryItem(name: "q", value: name))
        }
        components.queryItems = items
        return components.url
    }
}

/// A walking ETA without MapKit types, so it can cross concurrency boundaries.
struct WalkingETA: Sendable {
    let travelTime: TimeInterval
    let distance: CLLocationDistance

    var minutes: Int { max(1, Int((travelTime / 60).rounded())) }
}

enum DirectionsError: Error {
    case noRoute
}

/// Apple's walking directions. These are the app's only network requests.
@MainActor
enum DirectionsService {
    static func mapItem(at point: GeoPoint, name: String? = nil) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: point.coordinate))
        item.name = name
        return item
    }

    private static func walkingRequest(from start: GeoPoint, to end: GeoPoint) -> MKDirections.Request {
        let request = MKDirections.Request()
        request.source = mapItem(at: start)
        request.destination = mapItem(at: end)
        request.transportType = .walking
        return request
    }

    static func walkingRoute(from start: GeoPoint, to end: GeoPoint) async throws -> MKRoute {
        let response = try await MKDirections(request: walkingRequest(from: start, to: end)).calculate()
        guard let route = response.routes.first else { throw DirectionsError.noRoute }
        return route
    }

    static func walkingETA(from start: GeoPoint, to end: GeoPoint) async throws -> WalkingETA {
        let response = try await MKDirections(request: walkingRequest(from: start, to: end)).calculateETA()
        return WalkingETA(travelTime: response.expectedTravelTime, distance: response.distance)
    }

    /// Opens Apple Maps with walking directions to a place.
    static func openWalkingDirections(to point: GeoPoint, name: String) {
        mapItem(at: point, name: name).openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
        ])
    }
}

extension MKMapRect {
    /// The rect grown by a fraction of its size on every side, so routes don't touch the edges.
    func padded(by fraction: Double, minimumSize: Double = 400) -> MKMapRect {
        let width = Swift.max(size.width, minimumSize)
        let height = Swift.max(size.height, minimumSize)
        let centred = MKMapRect(x: midX - width / 2, y: midY - height / 2, width: width, height: height)
        return centred.insetBy(dx: -width * fraction, dy: -height * fraction)
    }
}
