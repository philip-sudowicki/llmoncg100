import SwiftUI

/// Shows the Tide profile as onboarding on first launch, then the map. Also loads places and
/// keeps the clock fresh so statuses change while the app is open.
struct RootView: View {
    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if profileStore.hasCompletedOnboarding {
                MapScreen()
            } else {
                ProfileView(mode: .onboarding)
            }
        }
        .task {
            await placeStore.load()
        }
        .task {
            await placeStore.runClock()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                placeStore.refreshNow()
            }
        }
    }
}

#Preview("Map") {
    RootView()
        .previewEnvironment()
}

#Preview("First launch") {
    RootView()
        .previewEnvironment(onboarded: false)
}
