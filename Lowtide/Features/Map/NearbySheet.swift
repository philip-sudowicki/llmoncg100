import SwiftUI
import UIKit

/// The persistent bottom sheet, like Apple Maps. It holds the nearby list and, when a pin or row
/// is tapped, that place's page in a `NavigationStack`.
struct NearbySheet: View {
    @Environment(MapModel.self) private var mapModel

    var body: some View {
        @Bindable var mapModel = mapModel

        NavigationStack(path: $mapModel.path) {
            NearbyList()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: PlaceRoute.self) { route in
                    PlaceDetailView(placeID: route.placeID)
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
        .onChange(of: mapModel.path) {
            mapModel.pathChanged()
        }
        .presentationDetents([MapModel.peekDetent, .medium, .large], selection: $mapModel.detent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationCornerRadius(26)
        .presentationBackground(Color.surface)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
        // The map is already presenting this sheet, so everything else is presented from here.
        .fullScreenCover(isPresented: $mapModel.isShowingProfile) {
            ProfileView(mode: .edit)
        }
        .sheet(item: $mapModel.checkInPlace) { place in
            CheckInView(place: place)
        }
        .fullScreenCover(isPresented: $mapModel.isShowingLowWater) {
            LowWaterView()
        }
    }
}

/// "Low tide near you": the Find low water button, nearby places and a check-in row.
struct NearbyList: View {
    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(PersonalStore.self) private var personalStore
    @Environment(LocationService.self) private var locationService
    @Environment(MapModel.self) private var mapModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        let engine = profileStore.engine
        let minute = placeStore.minuteOfDay
        let reference = locationService.point ?? placeStore.centre ?? .centralLondon
        let snapshots = placeStore.places.map {
            PlaceSnapshot(place: $0, location: placeStore.location(of: $0), engine: engine, minute: minute, from: reference)
        }
        let listed = mapModel.filter.listed(snapshots)
        let nearestOpen = snapshots.filter(\.isOpen).min { $0.distance < $1.distance }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        title
                        Spacer(minLength: 8)
                        asOf(minute)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        title
                        asOf(minute)
                    }
                }

                if placeStore.isFallbackCentre {
                    locationOffNotice
                }

                Button {
                    mapModel.isShowingLowWater = true
                } label: {
                    Label("Find low water", systemImage: "water.waves")
                }
                .buttonStyle(.primary)
                .accessibilityHint("Finds the nearest calm place and walks you there")

                VStack(spacing: 0) {
                    if listed.isEmpty {
                        emptyState
                    }
                    ForEach(listed) { snapshot in
                        PlaceRow(snapshot: snapshot, curve: engine.curve(for: snapshot.place, step: 60), now: minute) {
                            mapModel.showDetail(for: snapshot.id)
                        }
                        Hairline()
                    }
                    Button {
                        mapModel.checkInPlace = nearestOpen?.place
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("How's the tide where you are?")
                                    .font(.headline)
                                if let nearestOpen {
                                    Text("At \(nearestOpen.place.name)")
                                        .font(.subheadline)
                                        .foregroundStyle(.inkSecondary)
                                }
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.inkSecondary)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(.calmDeep)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(nearestOpen == nil)
                    .accessibilityHint(nearestOpen.map { "Check in at \($0.place.name)" } ?? "Nothing is open nearby")

                    // Confirms a check-in made from this row, whose place may not be in the list above.
                    if let nearestOpen, let checkIn = personalStore.latestCheckIns[nearestOpen.id],
                       Calendar.current.isDate(checkIn.date, inSameDayAs: placeStore.now) {
                        HStack(spacing: 8) {
                            StatusGlyph(status: checkIn.feeling.status)
                            Text("\(nearestOpen.place.name): \(TideText.lowercasedFirst(TideText.checkIn(checkIn.feeling, at: checkIn.date, today: placeStore.now)))")
                                .font(.subheadline)
                                .foregroundStyle(.inkSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .background(Color.surface)
    }

    /// Shown while places are laid out around central London because location is off or unavailable.
    private var locationOffNotice: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Location is off", systemImage: "location.slash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.ink)
            Text("These sample places are shown around central London, and walking times are from there.")
                .font(.subheadline)
                .foregroundStyle(.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if locationService.isUnavailable, let settings = URL(string: UIApplication.openSettingsURLString) {
                Button("Turn on location in Settings") {
                    openURL(settings)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.calmDeep)
                .frame(minHeight: 44)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var title: some View {
        Text(mapModel.filter.calmOnly ? "Low tide near you" : "Places near you")
            .font(.title2.bold())
            .foregroundStyle(.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func asOf(_ minute: Int) -> some View {
        Text("As of \(TideText.clock(minute))")
            .font(.footnote)
            .foregroundStyle(.inkSecondary)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mapModel.filter.calmOnly ? "Nothing matching is calm for you right now." : "No places match.")
                .font(.headline)
                .foregroundStyle(.ink)
            if mapModel.filter.calmOnly {
                Text("Turn off Calm now to see every place and when it will be calm.")
                    .font(.subheadline)
                    .foregroundStyle(.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
}

/// A nearby place: icon tile, name, status line, today's sparkline and a chevron.
struct PlaceRow: View {
    let snapshot: PlaceSnapshot
    let curve: [TidePoint]
    let now: Int
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let line = snapshot.statusLine(now: now)
        Button(action: action) {
            HStack(spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                    IconTile(systemImage: snapshot.place.category.symbolName)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.place.name)
                        .font(.headline)
                        .foregroundStyle(.ink)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let status = snapshot.status {
                            StatusGlyph(status: status)
                        }
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(.inkSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if !dynamicTypeSize.isAccessibilitySize {
                    TideSparkline(points: curve, now: now)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.inkSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(snapshot.place.name), \(line)")
        .accessibilityHint("Shows the tide forecast")
    }
}

#Preview("Sheet") {
    Color.ground
        .sheet(isPresented: .constant(true)) {
            NearbySheet()
        }
        .previewEnvironment()
}

#Preview("Sheet, largest text") {
    Color.ground
        .sheet(isPresented: .constant(true)) {
            NearbySheet()
        }
        .previewEnvironment()
        .dynamicTypeSize(.accessibility3)
}
