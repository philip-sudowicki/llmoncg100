import SwiftData
import SwiftUI
import UserNotifications

@main
struct LowtideApp: App {
    private let container: ModelContainer
    private let notificationPresenter = NotificationPresenter()

    @State private var placeStore: PlaceStore
    @State private var profileStore: ProfileStore
    @State private var personalStore: PersonalStore
    @State private var locationService = LocationService()
    @State private var mapModel = MapModel()

    init() {
        let container = Persistence.makeContainer()
        self.container = container
        _placeStore = State(initialValue: PlaceStore())
        _profileStore = State(initialValue: ProfileStore(context: container.mainContext))
        _personalStore = State(initialValue: PersonalStore(context: container.mainContext))
        UNUserNotificationCenter.current().delegate = notificationPresenter
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(placeStore)
                .environment(profileStore)
                .environment(personalStore)
                .environment(locationService)
                .environment(mapModel)
                .tint(.calmDeep)
        }
        .modelContainer(container)
    }
}
