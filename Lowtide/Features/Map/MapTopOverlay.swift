import SwiftUI

/// Search field, profile button, filter chips and legend floating above the map.
struct MapTopOverlay: View {
    @Environment(MapModel.self) private var mapModel

    var body: some View {
        @Bindable var mapModel = mapModel

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SearchField(text: $mapModel.filter.search)
                CircleIconButton(systemImage: "person.crop.circle", label: "Tide profile", background: .surface) {
                    mapModel.isShowingProfile = true
                }
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: "Calm now", isSelected: mapModel.filter.calmOnly, glyph: .calm, floating: true) {
                        mapModel.filter.calmOnly.toggle()
                    }
                    ForEach(CategoryFilter.allCases) { category in
                        Chip(title: category.title, isSelected: mapModel.filter.category == category, showsCheckmark: false, floating: true) {
                            mapModel.filter.category = mapModel.filter.category == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()

            TideLegend()
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
}

/// "Search calm places", filtering places by name.
struct SearchField: View {
    @Binding var text: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.inkSecondary)
                .accessibilityHidden(true)
            TextField(text: $text, prompt: Text(dynamicTypeSize.isAccessibilitySize ? "Search" : "Search calm places").foregroundStyle(.inkSecondary)) {
                Text("Search calm places")
            }
            .foregroundStyle(.ink)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.inkSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, text.isEmpty ? 14 : 0)
        .frame(minHeight: 48)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

#Preview("Top overlay") {
    MapTopOverlay()
        .previewEnvironment()
        .background(Color.ground)
}
