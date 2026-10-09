import MapKit

/// A walking route reduced to plain, `Sendable` values.
struct WalkingRoute: Equatable, Sendable {
    struct Step: Equatable, Sendable {
        let instruction: String
        let distance: Double
    }

    let points: [GeoPoint]
    let travelTime: TimeInterval
    let distance: Double
    let steps: [Step]

    var minutes: Int { Walking.minutes(forTravelTime: travelTime) }

    /// The first step with words in it. MapKit's first step is usually an empty "start".
    var firstInstruction: Step? {
        steps.first { !$0.instruction.isEmpty }
    }

    /// The step after `firstInstruction`, for "then 120 m along the water".
    var followingStep: Step? {
        guard let first = firstInstruction, let index = steps.firstIndex(of: first) else { return nil }
        let next = steps.index(after: index)
        return next < steps.endIndex ? steps[next] : nil
    }

    var coordinates: [CLLocationCoordinate2D] {
        points.map(\.coordinate)
    }
}

extension WalkingRoute {
    init(route: MKRoute) {
        let polyline = route.polyline
        var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        self.init(
            points: coordinates.map(GeoPoint.init),
            travelTime: route.expectedTravelTime,
            distance: route.distance,
            steps: route.steps.map { Step(instruction: $0.instructions, distance: $0.distance) }
        )
    }
}

enum DirectionsError: Error {
    case noRoute
}

/// Walking directions from Apple's MapKit. The only network use in v1 besides map tiles.
@MainActor
enum DirectionsService {
    static func walkingRoute(from origin: GeoPoint, to destination: GeoPoint) async throws -> WalkingRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .walking
        let directions = MKDirections(request: request)
        return try await withCheckedThrowingContinuation { continuation in
            directions.calculate { @Sendable response, error in
                if let route = response?.routes.first {
                    continuation.resume(returning: WalkingRoute(route: route))
                } else {
                    continuation.resume(throwing: error ?? DirectionsError.noRoute)
                }
            }
        }
    }

    /// Opens Apple Maps with walking directions to a place.
    static func openWalkingDirections(to destination: GeoPoint, name: String) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        item.name = name
        _ = item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    /// A camera region that fits the route, nudged up so the bottom sheet does not cover it.
    static func region(fitting points: [GeoPoint], bottomInset: Double = 0.35) -> MKCoordinateRegion? {
        guard let first = points.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for point in points {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        let latSpan = max(maxLat - minLat, 0.002) * 1.6 / (1 - bottomInset)
        let lonSpan = max(maxLon - minLon, 0.002) * 1.6
        let centre = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2 - latSpan * bottomInset / 2,
            longitude: (minLon + maxLon) / 2
        )
        return MKCoordinateRegion(center: centre, span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan))
    }
}
