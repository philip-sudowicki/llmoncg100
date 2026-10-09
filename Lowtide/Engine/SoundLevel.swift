import Foundation

/// Converts microphone levels to approximate sound pressure and plain-English descriptions.
enum SoundLevel {
    /// Approximate offset from dBFS (digital full scale) to dB SPL for an iPhone's built-in
    /// microphone with the audio session in `.measurement` mode (no automatic gain).
    ///
    /// A full-scale signal is roughly 100 dB SPL on recent iPhones, so a quiet room that
    /// measures about -60 dBFS reads about 40 dB. This varies by model and case. Readings are
    /// labelled "approximate" in the UI. To calibrate a device, compare against a reference
    /// meter in a steady noise and adjust this value.
    static let calibrationOffset = 100.0

    /// Readings are clamped to this range. Below 30 dB the microphone's own noise dominates.
    static let range = 30.0...110.0

    /// Approximate dB SPL from the mean of squared samples (a power average, like Leq).
    static func decibels(meanSquare: Double) -> Double {
        guard meanSquare > 0, meanSquare.isFinite else { return range.lowerBound }
        let fullScale = 10 * log10(meanSquare)
        return clamp(fullScale + calibrationOffset)
    }

    /// Approximate dB SPL from an RMS amplitude in the range 0 to 1.
    static func decibels(rms: Double) -> Double {
        decibels(meanSquare: rms * rms)
    }

    static func clamp(_ decibels: Double) -> Double {
        min(max(decibels, range.lowerBound), range.upperBound)
    }

    /// "Quiet conversation level" and so on.
    static func describe(_ decibels: Double) -> String {
        switch decibels {
        case ..<40: "Very quiet"
        case ..<50: "Quiet conversation level"
        case ..<60: "Normal conversation level"
        case ..<70: "Busy café level"
        case ..<80: "Loud, like busy traffic"
        default: "Very loud"
        }
    }

    /// A 1 to 5 meter level for a reading between 30 and 90 dB.
    static func meterLevel(_ decibels: Double) -> Int {
        let fraction = (decibels - 30) / 60
        return min(max(1 + Int((fraction * 4).rounded()), 1), 5)
    }

    /// Word for the Noise row in "How it feels", for example "Quiet".
    static func noiseWord(_ decibels: Double) -> String {
        switch decibels {
        case ..<45: "Very quiet"
        case ..<50: "Quiet"
        case ..<58: "Gentle hum"
        case ..<66: "Lively"
        default: "Loud"
        }
    }

    /// Rounds to the nearest 5 dB for "about 45 dB".
    static func roundedForDisplay(_ decibels: Double) -> Int {
        Int((decibels / 5).rounded()) * 5
    }
}
