import Foundation

/// A latitude and longitude without a CoreLocation dependency, so the engine stays pure Swift.
struct GeoPoint: Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    /// Used when location permission is denied or unavailable.
    static let centralLondon = GeoPoint(latitude: 51.5074, longitude: -0.1278)

    private static let metresPerDegreeLatitude = 111_320.0
    private static let earthRadius = 6_371_000.0

    /// The point a metre offset away. Accurate to well under a metre at city scale.
    func offset(by offset: MetreOffset) -> GeoPoint {
        let latitudeDelta = offset.north / Self.metresPerDegreeLatitude
        let metresPerDegreeLongitude = Self.metresPerDegreeLatitude * cos(latitude * .pi / 180)
        let longitudeDelta = metresPerDegreeLongitude > 0 ? offset.east / metresPerDegreeLongitude : 0
        return GeoPoint(latitude: latitude + latitudeDelta, longitude: longitude + longitudeDelta)
    }

    /// Great-circle distance in metres.
    func distance(to other: GeoPoint) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * Self.earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// Straight-line walking estimates for lists. Find low water uses real MapKit ETAs instead.
enum Walking {
    static let metresPerMinute = 80.0
    /// Streets are rarely straight, so a straight line is stretched by this factor.
    static let detourFactor = 1.25

    static func minutes(forStraightLineMetres metres: Double) -> Int {
        max(1, Int((metres * detourFactor / metresPerMinute).rounded()))
    }
}
