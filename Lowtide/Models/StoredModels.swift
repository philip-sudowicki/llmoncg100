import Foundation
import SwiftData

// On-device persistence with SwiftData. Nothing here is synced or uploaded.

/// The user's Tide profile.
@Model
final class StoredProfile {
    var noise: String = Sensitivity.moderate.rawValue
    var sudden: String = Sensitivity.moderate.rawValue
    var light: String = Sensitivity.moderate.rawValue
    var crowd: String = Sensitivity.moderate.rawValue
    var smell: String = Sensitivity.moderate.rawValue
    var helps: [String] = []
    var gentleAlerts: Bool = false
    var shareSoundReadings: Bool = true
    var trustedPerson: String = ""
    var updatedAt: Date = Date.now

    init() {}

    var profile: SensoryProfile {
        func sensitivity(_ raw: String) -> Sensitivity { Sensitivity(rawValue: raw) ?? .moderate }
        return SensoryProfile(
            noise: sensitivity(noise),
            sudden: sensitivity(sudden),
            light: sensitivity(light),
            crowd: sensitivity(crowd),
            smell: sensitivity(smell),
            helps: Set(helps.compactMap(Help.init(rawValue:))),
            gentleAlerts: gentleAlerts,
            shareSoundReadings: shareSoundReadings,
            trustedPerson: trustedPerson
        )
    }

    func update(from profile: SensoryProfile) {
        noise = profile.noise.rawValue
        sudden = profile.sudden.rawValue
        light = profile.light.rawValue
        crowd = profile.crowd.rawValue
        smell = profile.smell.rawValue
        helps = profile.helps.map(\.rawValue).sorted()
        gentleAlerts = profile.gentleAlerts
        shareSoundReadings = profile.shareSoundReadings
        trustedPerson = profile.trustedPerson
        updatedAt = .now
    }
}

/// A favourite place.
@Model
final class SavedPlace {
    @Attribute(.unique) var placeID: String
    var savedAt: Date

    init(placeID: String, savedAt: Date = .now) {
        self.placeID = placeID
        self.savedAt = savedAt
    }
}

/// An anonymous check-in. It is not linked to the profile.
@Model
final class CheckIn {
    var placeID: String
    var date: Date
    var feeling: String
    var noticed: [String]
    /// Approximate dB SPL. Only the number is kept, never audio.
    var decibels: Double?

    init(placeID: String, date: Date = .now, feeling: CheckInFeeling, noticed: [NoticedTrigger], decibels: Double?) {
        self.placeID = placeID
        self.date = date
        self.feeling = feeling.rawValue
        self.noticed = noticed.map(\.rawValue).sorted()
        self.decibels = decibels
    }

    var checkInFeeling: CheckInFeeling {
        CheckInFeeling(rawValue: feeling) ?? .okay
    }
}
