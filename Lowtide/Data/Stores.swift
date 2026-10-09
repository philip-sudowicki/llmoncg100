import Foundation
import Observation
import SwiftData

/// The places, and the demo centre their metre offsets are measured from.
@MainActor
@Observable
final class PlaceStore {
    private(set) var places: [Place]
    /// The user's first location fix this launch, or central London as a fallback.
    private(set) var anchor: GeoPoint?
    /// Whether `anchor` is the London fallback rather than the user's location.
    private(set) var anchorIsFallback = false
    private(set) var loadFailed = false

    @ObservationIgnored private let repository: any PlaceRepository

    init(repository: any PlaceRepository, places: [Place] = [], anchor: GeoPoint? = nil) {
        self.repository = repository
        self.places = places
        self.anchor = anchor
    }

    func loadIfNeeded() async {
        guard places.isEmpty else { return }
        do {
            places = try await repository.fetchPlaces()
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    func setAnchor(_ point: GeoPoint, isFallback: Bool) {
        anchor = point
        anchorIsFallback = isFallback
    }

    func place(id: String) -> Place? {
        places.first { $0.id == id }
    }

    func position(of place: Place) -> GeoPoint? {
        anchor.map(place.position(around:))
    }
}

/// The Tide profile. Edits apply immediately, so the map recolours as the user changes it.
@MainActor
@Observable
final class ProfileStore {
    var profile: SensoryProfile
    /// False until the first-launch onboarding is saved.
    private(set) var hasSavedProfile: Bool

    @ObservationIgnored private let context: ModelContext?

    init(context: ModelContext) {
        self.context = context
        if let stored = try? context.fetch(FetchDescriptor<StoredProfile>()).first {
            profile = stored.profile
            hasSavedProfile = true
        } else {
            profile = .standard
            hasSavedProfile = false
        }
    }

    /// A store that keeps nothing, for previews and demos.
    init(profile: SensoryProfile, hasSavedProfile: Bool = true) {
        self.context = nil
        self.profile = profile
        self.hasSavedProfile = hasSavedProfile
    }

    func save() {
        hasSavedProfile = true
        guard let context else { return }
        let stored: StoredProfile
        if let existing = try? context.fetch(FetchDescriptor<StoredProfile>()).first {
            stored = existing
        } else {
            stored = StoredProfile()
            context.insert(stored)
        }
        stored.update(from: profile)
        try? context.save()
    }
}
