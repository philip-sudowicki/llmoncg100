import SwiftUI

/// A place's page inside the bottom sheet. Filled in by milestone 3.
struct PlaceDetailView: View {
    let placeID: String

    @Environment(PlaceStore.self) private var placeStore
    @Environment(MapModel.self) private var mapModel

    var body: some View {
        ScrollView {
            if let place = placeStore.place(id: placeID) {
                HStack(alignment: .top) {
                    Text(place.name)
                        .font(.title2.bold())
                        .foregroundStyle(.ink)
                    Spacer()
                    CircleIconButton(systemImage: "xmark", label: "Close") {
                        mapModel.closeDetail()
                    }
                }
                .padding(20)
            }
        }
        .background(Color.surface)
    }
}

#Preview {
    PlaceDetailView(placeID: "marlow-street-library")
        .previewEnvironment()
}
