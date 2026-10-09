import SwiftUI

/// Loads places, keeps the clock fresh and shows the map.
struct RootView: View {
    @Environment(PlaceStore.self) private var placeStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        MapScreen()
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

#Preview {
    RootView()
        .previewEnvironment()
}
