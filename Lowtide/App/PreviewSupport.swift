import SwiftData
import SwiftUI

/// Sample data and stores for SwiftUI previews.
@MainActor
enum PreviewData {
    /// The bundled sample places.
    static let places: [Place] = {
        guard let url = Bundle.main.url(forResource: "places", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let places = try? LocalPlaceRepository.decode(data) else { return [] }
        return places
    }()

    static let anchor = GeoPoint.londonFallback
    /// 2:10pm, the time shown in the mockup.
    static let minute = 14 * 60 + 10

    static var library: Place {
        places.first { $0.id == "marlow-street-library" } ?? places[0]
    }

    static func placeStore() -> PlaceStore {
        PlaceStore(repository: LocalPlaceRepository(), places: places, anchor: anchor)
    }

    static func container() -> ModelContainer {
        do {
            return try ModelContainer(
                for: StoredProfile.self, SavedPlace.self, CheckIn.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Preview container failed: \(error)")
        }
    }
}

extension View {
    /// Injects every store a screen expects, filled with sample data.
    @MainActor
    func previewEnvironment(
        profile: SensoryProfile = .standard,
        hasSavedProfile: Bool = true,
        minute: Int = PreviewData.minute
    ) -> some View {
        self
            .environment(PreviewData.placeStore())
            .environment(ProfileStore(profile: profile, hasSavedProfile: hasSavedProfile))
            .environment(LocationService())
            .environment(TideClock(fixedMinute: minute))
            .environment(NotificationService())
            .environment(MapModel())
            .modelContainer(PreviewData.container())
    }
}
