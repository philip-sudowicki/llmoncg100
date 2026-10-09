import SwiftUI

/// The search field, profile button, filter chips and legend floating over the map.
struct MapOverlay: View {
    @Bindable var model: MapModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SearchField(text: $model.filter.searchText)
                Button {
                    model.isShowingProfile = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.ink)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.surface))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tide profile")
                .accessibilityHint("Change what gets to you")
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(
                        title: "Calm now",
                        isSelected: model.filter.calmNow,
                        leading: {
                            WaveGlyph(count: 1)
                                .stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                .frame(width: 16, height: 10)
                                .accessibilityHidden(true)
                        },
                        action: { model.filter.calmNow.toggle() }
                    )
                    .accessibilityHint("Lists only places that are calm for you now")
                    ForEach(PlaceFilter.Chip.allCases) { chip in
                        Chip(chip.title, isSelected: model.filter.chips.contains(chip)) {
                            if model.filter.chips.contains(chip) {
                                model.filter.chips.remove(chip)
                            } else {
                                model.filter.chips.insert(chip)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

            StatusLegend()
                .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

/// "Search calm places", filtering places by name.
struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.inkSecondary)
                .accessibilityHidden(true)
            TextField("Search calm places", text: $text)
                .foregroundStyle(Color.ink)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.inkSecondary)
                        .frame(width: Metrics.minimumTapTarget, height: Metrics.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, text.isEmpty ? 14 : 2)
        .frame(minHeight: 50)
        .background(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous).fill(Color.surface))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    }
}

/// "Calm · Busy · High tide", each with its glyph.
struct StatusLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(TideStatus.allCases, id: \.self) { status in
                HStack(spacing: 5) {
                    StatusBadge(status: status, size: 16)
                    Text(status.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ink)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.surface))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend")
        .accessibilityValue("Calm has one wave, busy has two waves, high tide has three waves")
    }
}

#Preview("Map overlay") {
    MapOverlay(model: MapModel())
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.ground)
}
