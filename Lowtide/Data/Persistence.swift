import Foundation
import SwiftData

/// The user's Tide profile. There is at most one record.
@Model
final class ProfileRecord {
    var noise: String
    var sudden: String
    var light: String
    var crowd: String
    var smell: String
    var helps: [String]
    var gentleAlerts: Bool
    var shareSoundReadings: Bool
    var trustedPerson: String
    var updatedAt: Date

    init(profile: SensoryProfile) {
        noise = profile[.noise].rawValue
        sudden = profile[.sudden].rawValue
        light = profile[.light].rawValue
        crowd = profile[.crowd].rawValue
        smell = profile[.smell].rawValue
        helps = profile.helps.map(\.rawValue).sorted()
        gentleAlerts = profile.gentleAlerts
        shareSoundReadings = profile.shareSoundReadings
        trustedPerson = profile.trustedPerson
        updatedAt = Date()
    }

    func apply(_ profile: SensoryProfile) {
        noise = profile[.noise].rawValue
        sudden = profile[.sudden].rawValue
        light = profile[.light].rawValue
        crowd = profile[.crowd].rawValue
        smell = profile[.smell].rawValue
        helps = profile.helps.map(\.rawValue).sorted()
        gentleAlerts = profile.gentleAlerts
        shareSoundReadings = profile.shareSoundReadings
        trustedPerson = profile.trustedPerson
        updatedAt = Date()
    }

    var profile: SensoryProfile {
        let stored: [Factor: String] = [.noise: noise, .sudden: sudden, .light: light, .crowd: crowd, .smell: smell]
        return SensoryProfile(
            sensitivities: stored.compactMapValues(Sensitivity.init(rawValue:)),
            helps: Set(helps.compactMap(Help.init(rawValue:))),
            gentleAlerts: gentleAlerts,
            shareSoundReadings: shareSoundReadings,
            trustedPerson: trustedPerson
        )
    }
}

/// A place the user saved as a favourite.
@Model
final class SavedPlace {
    @Attribute(.unique) var placeID: String
    var savedAt: Date

    init(placeID: String, savedAt: Date = Date()) {
        self.placeID = placeID
        self.savedAt = savedAt
    }
}

/// A check-in kept on this iPhone. Only the decibel number is stored, never audio.
@Model
final class CheckIn {
    var placeID: String
    var feeling: String
    var noticed: [String]
    var decibels: Double?
    var createdAt: Date

    init(placeID: String, feeling: CheckInFeeling, noticed: [NoticedThing], decibels: Double?, createdAt: Date) {
        self.placeID = placeID
        self.feeling = feeling.rawValue
        self.noticed = noticed.map(\.rawValue)
        self.decibels = decibels
        self.createdAt = createdAt
    }
}

enum Persistence {
    static var schema: Schema { Schema([ProfileRecord.self, SavedPlace.self, CheckIn.self]) }

    /// The on-device store. Falls back to memory if the store can't open, so the app still launches.
    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [fallback])
        } catch {
            fatalError("Could not create even an in-memory store: \(error)")
        }
    }
}
