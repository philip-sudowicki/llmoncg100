import SwiftUI

/// Temporary root for milestone 1: lists the sample places with their status at the current time.
struct RootView: View {
    @State private var places: [Place] = []
    private let engine = TideEngine(profile: .standard)

    var body: some View {
        NavigationStack {
            List(places) { place in
                let minute = Calendar.current.component(.hour, from: .now) * 60 + Calendar.current.component(.minute, from: .now)
                HStack(spacing: 12) {
                    StatusBadge(status: engine.status(of: place, at: minute))
                    VStack(alignment: .leading) {
                        Text(place.name).foregroundStyle(.ink)
                        Text(TideText.nextChange(engine.nextChange(for: place, at: minute), now: minute))
                            .font(.subheadline)
                            .foregroundStyle(.inkSecondary)
                    }
                }
            }
            .navigationTitle("Lowtide")
        }
        .task {
            places = (try? LocalPlaceRepository().loadPlacesNow()) ?? []
        }
    }
}

#Preview {
    RootView()
}
