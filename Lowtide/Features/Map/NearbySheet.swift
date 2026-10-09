import SwiftUI

/// The persistent bottom sheet. A navigation stack inside it shows place details.
struct NearbySheet: View {
    @Environment(MapModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            NearbyList()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { id in
                    PlaceDetailView(placeID: id)
                }
        }
        .sheet(item: $model.checkInPlace) { place in
            CheckInView(place: place)
        }
        .sheet(isPresented: $model.isShowingProfile) {
            TideProfileView(mode: .editing)
        }
        .fullScreenCover(isPresented: $model.isShowingLowWater) {
            LowWaterView()
        }
    }
}

/// "Low tide near you": the Find low water button and a list of calm places by distance.
struct NearbyList: View {
    @Environment(MapModel.self) private var model
    @Environment(PlaceStore.self) private var placeStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(LocationService.self) private var location
    @Environment(TideClock.self) private var clock

    private var engine: TideEngine { TideEngine(profile: profileStore.profile) }

    private var rows: [PlaceSummary] {
        guard let anchor = placeStore.anchor else { return [] }
        let places = model.filter.listPlaces(placeStore.places, engine: engine, atMinute: clock.minuteOfDay)
        return PlaceSummary.make(
            places, engine: engine, minute: clock.minuteOfDay, anchor: anchor, origin: location.current ?? anchor
        )
    }

    /// The nearest open place, for "How's the tide where you are?".
    private var nearestOpen: Place? {
        guard let anchor = placeStore.anchor else { return nil }
        return PlaceSummary.make(
            placeStore.places, engine: engine, minute: clock.minuteOfDay, anchor: anchor, origin: location.current ?? anchor
        )
        .first { $0.status != nil }?.place
    }

    private var title: String {
        if model.filter.isSearching { return "Results" }
        return model.filter.calmNow ? "Low tide near you" : "Places near you"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)

                Button {
                    model.isShowingLowWater = true
                } label: {
                    HStack(spacing: 10) {
                        WaveGlyph(count: 2)
                            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 24, height: 16)
                            .accessibilityHidden(true)
                        Text("Find low water")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityHint("Finds the nearest calm place, with a breathing guide")

                list

                if let place = nearestOpen {
                    Divider()
                    Button {
                        model.checkInPlace = place
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle")
                                .font(.title3)
                                .accessibilityHidden(true)
                            Text("How's the tide where you are?")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.inkSecondary)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(Color.calmDeep)
                        .frame(minHeight: Metrics.minimumTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Check in at \(place.name)")
                }

                if placeStore.anchorIsFallback {
                    Label(
                        "Your location isn't available, so the sample places are shown around central London.",
                        systemImage: "location.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private var list: some View {
        if placeStore.anchor == nil {
            Text(placeStore.loadFailed ? "Places couldn't be loaded." : "Finding calm places near you…")
                .font(.body)
                .foregroundStyle(Color.inkSecondary)
        } else if rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.filter.isSearching ? "No places match your search." : "Nothing is calm nearby right now.")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                if model.filter.calmNow, !model.filter.isSearching {
                    Text("Turn off Calm now to see every place and when it gets calmer.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    Button {
                        model.showPlace(row.id)
                    } label: {
                        PlaceRow(summary: row, engine: engine, minute: clock.minuteOfDay)
                    }
                    .buttonStyle(.plain)
                    if row.id != rows.last?.id {
                        Divider().padding(.leading, 58)
                    }
                }
            }
        }
    }
}

/// One place in the sheet: icon tile, name, status line, sparkline and chevron.
struct PlaceRow: View {
    let summary: PlaceSummary
    let engine: TideEngine
    let minute: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
                IconTile(systemImage: summary.place.category.symbol)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.place.name)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text("\(summary.statusLine) · \(summary.walkText)")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !dynamicTypeSize.isAccessibilitySize {
                Sparkline(
                    points: engine.series(for: summary.place, stepMinutes: 30),
                    domain: summary.place.hours.open...summary.place.hours.close,
                    now: minute
                )
                .frame(width: 64, height: 30)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .frame(minHeight: Metrics.minimumTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.place.name)
        .accessibilityValue("\(summary.spokenStatus), \(summary.walkMinutes) minute walk")
        .accessibilityHint("Shows details")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Sheet") {
    NearbySheet()
        .previewEnvironment()
}
