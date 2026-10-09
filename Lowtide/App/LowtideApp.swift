import SwiftData
import SwiftUI

@main
struct LowtideApp: App {
    private let container: ModelContainer
    @State private var placeStore = PlaceStore(repository: LocalPlaceRepository())
    @State private var profileStore: ProfileStore
    @State private var location = LocationService()
    @State private var clock = TideClock(fixedMinute: DemoOptions.fixedMinute)
    @State private var notifications = NotificationService()

    init() {
        let demo = DemoOptions.screen
        let container = Self.makeContainer(inMemory: demo != nil)
        self.container = container
        if let demo {
            // Demo launches never touch saved data.
            _profileStore = State(initialValue: ProfileStore(profile: .standard, hasSavedProfile: demo != .onboarding))
        } else {
            _profileStore = State(initialValue: ProfileStore(context: container.mainContext))
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(placeStore)
                .environment(profileStore)
                .environment(location)
                .environment(clock)
                .environment(notifications)
        }
        .modelContainer(container)
    }

    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema([StoredProfile.self, SavedPlace.self, CheckIn.self])
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        } catch {
            // If the on-device store can't be opened, keep the app usable for this session.
            do {
                return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } catch {
                fatalError("Lowtide could not create its data store: \(error)")
            }
        }
    }
}

/// Shows the Tide profile as onboarding on first launch, then the map.
struct RootView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(TideClock.self) private var clock

    var body: some View {
        Group {
            if profileStore.hasSavedProfile {
                MapScreen()
            } else {
                TideProfileView(mode: .onboarding)
            }
        }
        .task { await clock.run() }
    }
}

#Preview("First launch") {
    RootView()
        .previewEnvironment(hasSavedProfile: false)
}

#Preview("Returning") {
    RootView()
        .previewEnvironment()
}
