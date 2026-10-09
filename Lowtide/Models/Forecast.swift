import Foundation

/// One moment's sensory values, each normalised from 0 to 1.
struct FactorValues: Hashable, Sendable {
    var noise: Double
    var sudden: Double
    var light: Double
    var crowd: Double
    var smell: Double

    subscript(factor: Factor) -> Double {
        switch factor {
        case .noise: noise
        case .sudden: sudden
        case .light: light
        case .crowd: crowd
        case .smell: smell
        }
    }
}

/// A place's typical day: 24 hourly values for every factor.
///
/// Value `i` describes the top of hour `i`. Times in between are interpolated linearly,
/// so the engine can talk about half-hours ("Calm until 3:30pm").
struct HourlyForecast: Hashable, Sendable {
    static let hoursPerDay = 24

    /// Typical loudness in decibels. Converted to a 0–1 value with `TideEngine.normalisedNoise`.
    let noiseDB: [Double]
    let sudden: [Double]
    let light: [Double]
    let crowd: [Double]
    let smell: [Double]

    func decibels(atMinute minute: Double) -> Double {
        Self.interpolate(noiseDB, atMinute: minute)
    }

    func values(atMinute minute: Double) -> FactorValues {
        FactorValues(
            noise: TideEngine.normalisedNoise(decibels: decibels(atMinute: minute)),
            sudden: Self.interpolate(sudden, atMinute: minute),
            light: Self.interpolate(light, atMinute: minute),
            crowd: Self.interpolate(crowd, atMinute: minute),
            smell: Self.interpolate(smell, atMinute: minute)
        )
    }

    private static func interpolate(_ hourly: [Double], atMinute minute: Double) -> Double {
        guard hourly.count == hoursPerDay else { return 0 }
        let hour = min(max(minute, 0), 24 * 60) / 60
        let lower = Int(hour.rounded(.down))
        let fraction = hour - Double(lower)
        let start = hourly[lower % hoursPerDay]
        let end = hourly[(lower + 1) % hoursPerDay]
        return start + (end - start) * fraction
    }
}

/// A latitude and longitude that is `Sendable` and `Equatable`, unlike `CLLocationCoordinate2D`.
struct GeoPoint: Hashable, Sendable {
    var latitude: Double
    var longitude: Double

    /// Used when location is unavailable or permission is denied.
    static let londonFallback = GeoPoint(latitude: 51.5074, longitude: -0.1278)

    private static let metresPerDegreeLatitude = 111_320.0
    private static let earthRadius = 6_371_000.0

    func offsetBy(east: Double, north: Double) -> GeoPoint {
        let metresPerDegreeLongitude = Self.metresPerDegreeLatitude * cos(latitude * .pi / 180)
        return GeoPoint(
            latitude: latitude + north / Self.metresPerDegreeLatitude,
            longitude: longitude + east / metresPerDegreeLongitude
        )
    }

    /// Great-circle distance in metres.
    func distance(to other: GeoPoint) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (other.longitude - longitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * Self.earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}
