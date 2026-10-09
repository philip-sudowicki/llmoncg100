import Foundation

/// Sound levels: conversion from microphone samples and plain-English descriptions.
enum SoundLevel {
    static let minimumDecibels = 30.0
    static let maximumDecibels = 110.0

    /// Approximate dB SPL from the RMS of full-scale samples (1.0 = 0 dBFS).
    ///
    /// `calibrationOffset` maps dBFS to dB SPL. See `SoundMeter.calibrationOffset`.
    static func decibels(fromRMS rms: Double, calibrationOffset: Double) -> Double {
        guard rms > 0 else { return minimumDecibels }
        return clamp(20 * log10(rms) + calibrationOffset)
    }

    static func clamp(_ decibels: Double) -> Double {
        min(max(decibels, minimumDecibels), maximumDecibels)
    }

    /// For a sound reading: "Quiet conversation level".
    static func description(forDecibels decibels: Double) -> String {
        switch decibels {
        case ..<40: "Very quiet, like a library"
        case ..<50: "Quiet conversation level"
        case ..<60: "Normal conversation level"
        case ..<70: "Busy café level"
        case ..<80: "Loud, like a busy street"
        case ..<90: "Very loud, like a passing train"
        default: "Extremely loud"
        }
    }

    /// For the "How it feels" noise row: "Quiet".
    static func feel(forDecibels decibels: Double) -> String {
        switch decibels {
        case ..<42: "Very quiet"
        case ..<55: "Quiet"
        case ..<63: "Lively"
        case ..<72: "Loud"
        default: "Very loud"
        }
    }

    /// "about 45 dB", rounded to the nearest 5.
    static func approximate(_ decibels: Double) -> String {
        "about \(Int((decibels / 5).rounded()) * 5) dB"
    }
}

/// Plain-English descriptions for the "How it feels" rows.
enum FeelText {
    static func light(_ value: Double) -> String {
        switch value {
        case ..<0.2: "Soft, even light"
        case ..<0.45: "Bright in places"
        case ..<0.7: "Bright light"
        default: "Harsh or flickering light"
        }
    }

    static func crowd(_ value: Double) -> String {
        switch value {
        case ..<0.2: "A few people, plenty of space"
        case ..<0.45: "Some people, still room"
        case ..<0.7: "Busy, harder to find space"
        default: "Packed"
        }
    }

    static func smell(_ value: Double) -> String {
        switch value {
        case ..<0.15: "Nothing noticed"
        case ..<0.4: "Faint smells"
        case ..<0.7: "Noticeable smells"
        default: "Strong smells"
        }
    }

    /// Filled steps on a five-step meter. Always at least one, so the meter reads as a meter.
    static func meterSteps(_ value: Double, steps: Int = 5) -> Int {
        min(max(Int((value * Double(steps)).rounded(.up)), 1), steps)
    }
}

/// Walking estimates for list rows, before real directions are requested.
enum Walking {
    /// About 4.8 km/h.
    static let metresPerMinute = 80.0
    /// Streets are rarely straight lines.
    static let detourFactor = 1.3

    static func estimatedMinutes(straightLineMetres metres: Double) -> Int {
        max(1, Int((metres * detourFactor / metresPerMinute).rounded(.up)))
    }

    static func minutes(forTravelTime seconds: Double) -> Int {
        max(1, Int((seconds / 60).rounded()))
    }

    /// "160 m" or "1.2 km".
    static func distanceText(metres: Double) -> String {
        if metres < 1000 {
            return "\(max(10, Int((metres / 10).rounded()) * 10)) m"
        }
        return String(format: "%.1f km", metres / 1000)
    }

    /// "two minutes" for small numbers, "12 minutes" otherwise.
    static func spokenMinutes(_ minutes: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        let number = minutes < words.count ? words[minutes] : "\(minutes)"
        return minutes == 1 ? "\(number) minute" : "\(number) minutes"
    }
}

/// Picks candidates for "Find low water": open, calm now and nearest by straight-line distance.
enum LowWaterPicker {
    static func candidates(
        from places: [Place],
        engine: TideEngine,
        atMinute minute: Int,
        origin: GeoPoint,
        anchor: GeoPoint,
        limit: Int = 3
    ) -> [Place] {
        places
            .filter { engine.status(of: $0, atMinute: minute) == .calm }
            .map { (place: $0, distance: origin.distance(to: $0.position(around: anchor))) }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map(\.place)
    }
}

/// The map's filter chips and search field.
struct PlaceFilter: Equatable, Sendable {
    enum Chip: String, CaseIterable, Identifiable, Sendable {
        case cafes, libraries, parks, quietRooms

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cafes: "Cafés"
            case .libraries: "Libraries"
            case .parks: "Parks"
            case .quietRooms: "Quiet rooms"
            }
        }

        var category: PlaceCategory {
            switch self {
            case .cafes: .cafe
            case .libraries: .library
            case .parks: .park
            case .quietRooms: .quietRoom
            }
        }
    }

    /// Limits the sheet's list to places that are calm now. The map still shows every status,
    /// so people can see what to avoid.
    var calmNow = true
    var chips: Set<Chip> = []
    var searchText = ""

    var isSearching: Bool { !trimmedSearch.isEmpty }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Places shown as pins: category chips and search apply.
    func mapPlaces(_ places: [Place]) -> [Place] {
        places.filter { matchesCategory($0) && matchesSearch($0) }
    }

    /// Places listed in the sheet. "Calm now" applies too, unless the user is searching by name.
    func listPlaces(_ places: [Place], engine: TideEngine, atMinute minute: Int) -> [Place] {
        mapPlaces(places).filter { place in
            !calmNow || isSearching || engine.status(of: place, atMinute: minute) == .calm
        }
    }

    private func matchesCategory(_ place: Place) -> Bool {
        chips.isEmpty || chips.contains { $0.category == place.category }
    }

    private func matchesSearch(_ place: Place) -> Bool {
        let query = trimmedSearch
        return query.isEmpty || place.name.localizedCaseInsensitiveContains(query)
    }
}
