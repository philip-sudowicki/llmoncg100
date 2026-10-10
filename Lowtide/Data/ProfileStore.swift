import Foundation
import Observation
import SwiftData

/// The user's Tide profile, persisted with SwiftData. Saving a new profile recolours the map at once,
/// because every status is computed from `engine`.
@MainActor
@Observable
final class ProfileStore {
    private(set) var profile: SensoryProfile
    private(set) var hasCompletedOnboarding: Bool

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        let record = try? context.fetch(FetchDescriptor<ProfileRecord>()).first
        profile = record?.profile ?? .standard
        hasCompletedOnboarding = record != nil
    }

    var engine: TideEngine { TideEngine(profile: profile) }

    func save(_ newProfile: SensoryProfile) {
        let turnsAlertsOff = profile.gentleAlerts && !newProfile.gentleAlerts
        if let record = try? context.fetch(FetchDescriptor<ProfileRecord>()).first {
            record.apply(newProfile)
        } else {
            context.insert(ProfileRecord(profile: newProfile))
        }
        try? context.save()
        profile = newProfile
        hasCompletedOnboarding = true
        if turnsAlertsOff {
            // Gentle alerts is the master switch for Alert me.
            Task {
                await NotificationService.cancelAllCalmAlerts()
            }
        }
    }

    func setGentleAlerts(_ isOn: Bool) {
        var updated = profile
        updated.gentleAlerts = isOn
        save(updated)
    }
}
