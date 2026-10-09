import Foundation

/// Normalised factor values (0 to 1) at one moment.
struct FactorLevels: Equatable, Sendable {
    var noise: Double
    var sudden: Double
    var light: Double
    var crowd: Double
    var smell: Double

    init(noise: Double = 0, sudden: Double = 0, light: Double = 0, crowd: Double = 0, smell: Double = 0) {
        self.noise = noise
        self.sudden = sudden
        self.light = light
        self.crowd = crowd
        self.smell = smell
    }

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

/// A place's typical day: 24 hourly values per factor. Index 0 is midnight to 1am.
/// Noise is stored in dB and normalised with `clamp((dB - 40) / 40, 0, 1)`.
struct Forecast: Sendable, Decodable {
    static let hoursPerDay = 24

    let noiseDecibels: [Double]
    let noise: [Double]
    let sudden: [Double]
    let light: [Double]
    let crowd: [Double]
    let smell: [Double]

    init(noiseDecibels: [Double], sudden: [Double], light: [Double], crowd: [Double], smell: [Double]) throws {
        for series in [noiseDecibels, sudden, light, crowd, smell] where series.count != Self.hoursPerDay {
            throw ForecastError.wrongLength(series.count)
        }
        self.noiseDecibels = noiseDecibels
        self.noise = noiseDecibels.map(Self.normalisedNoise(decibels:))
        self.sudden = sudden.map(Self.clamped)
        self.light = light.map(Self.clamped)
        self.crowd = crowd.map(Self.clamped)
        self.smell = smell.map(Self.clamped)
    }

    private enum CodingKeys: String, CodingKey {
        case noiseDB, sudden, light, crowd, smell
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                noiseDecibels: container.decode([Double].self, forKey: .noiseDB),
                sudden: container.decode([Double].self, forKey: .sudden),
                light: container.decode([Double].self, forKey: .light),
                crowd: container.decode([Double].self, forKey: .crowd),
                smell: container.decode([Double].self, forKey: .smell)
            )
        } catch let error as ForecastError {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: error.description))
        }
    }

    /// `clamp((dB - 40) / 40, 0, 1)`: 40 dB or quieter is 0, 80 dB or louder is 1.
    static func normalisedNoise(decibels: Double) -> Double {
        clamped((decibels - 40) / 40)
    }

    static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    func series(for factor: Factor) -> [Double] {
        switch factor {
        case .noise: noise
        case .sudden: sudden
        case .light: light
        case .crowd: crowd
        case .smell: smell
        }
    }

    /// Values at a minute of the day, interpolated linearly between hourly values.
    func levels(at minute: Double) -> FactorLevels {
        FactorLevels(
            noise: Self.interpolate(noise, at: minute),
            sudden: Self.interpolate(sudden, at: minute),
            light: Self.interpolate(light, at: minute),
            crowd: Self.interpolate(crowd, at: minute),
            smell: Self.interpolate(smell, at: minute)
        )
    }

    /// Approximate sound level at a minute of the day.
    func decibels(at minute: Double) -> Double {
        Self.interpolate(noiseDecibels, at: minute)
    }

    /// Each hourly value describes the start of its hour. The day wraps from 11pm back to midnight.
    static func interpolate(_ values: [Double], at minute: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let minutesPerDay = Double(hoursPerDay * 60)
        let wrapped = (minute.truncatingRemainder(dividingBy: minutesPerDay) + minutesPerDay)
            .truncatingRemainder(dividingBy: minutesPerDay)
        let hour = Int(wrapped / 60)
        let fraction = (wrapped - Double(hour * 60)) / 60
        let current = values[hour % values.count]
        let next = values[(hour + 1) % values.count]
        return current + (next - current) * fraction
    }
}

enum ForecastError: Error, CustomStringConvertible {
    case wrongLength(Int)

    var description: String {
        switch self {
        case .wrongLength(let count): "Each forecast series needs 24 hourly values, found \(count)"
        }
    }
}
