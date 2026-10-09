import SwiftData
import SwiftUI

/// Sample stores for SwiftUI previews: the bundled places around central London at 2pm,
/// with the profile from the mockup.
@MainActor
enum PreviewSupport {
    static let mockupProfile = SensoryProfile(
        sensitivities: [.noise: .aLot, .sudden: .aLot, .light: .some, .crowd: .some, .smell: .aBit],
        helps: [.naturalLight, .cornerSeat, .quietRoom],
        gentleAlerts: false,
        shareSoundReadings: true,
        trustedPerson: "Sam"
    )

    static let places: [Place] = (try? LocalPlaceRepository().loadPlacesNow()) ?? []

    static func place(_ id: String = "marlow-street-library") -> Place {
        places.first { $0.id == id } ?? places[0]
    }

    static func placeStore() -> PlaceStore {
        PlaceStore(clock: .startingAt(minute: 14 * 60), places: places, centre: .centralLondon)
    }
}

extension View {
    /// Injects in-memory stores so previews never touch the real database.
    @MainActor
    func previewEnvironment(onboarded: Bool = true, mapModel: MapModel? = nil) -> some View {
        let container = Persistence.makeContainer(inMemory: true)
        let profileStore = ProfileStore(context: container.mainContext)
        if onboarded {
            profileStore.save(PreviewSupport.mockupProfile)
        }
        return self
            .environment(PreviewSupport.placeStore())
            .environment(profileStore)
            .environment(PersonalStore(context: container.mainContext))
            .environment(LocationService())
            .environment(mapModel ?? MapModel())
            .modelContainer(container)
            .tint(.calmDeep)
    }
}
