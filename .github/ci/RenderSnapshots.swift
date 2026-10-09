// CI only: copied into LowtideTests by .github/workflows/ios.yml to render long sections of the
// place page and other screens to PNGs for visual review. Does nothing unless
// LOWTIDE_SNAPSHOT_DIR is set.
import SwiftUI
import Testing
@testable import Lowtide

@MainActor
@Suite("Review snapshots")
struct RenderSnapshots {
    let directory = ProcessInfo.processInfo.environment["LOWTIDE_SNAPSHOT_DIR"].map(URL.init(fileURLWithPath:))

    private func render<V: View>(_ name: String, width: CGFloat = 393, dark: Bool = false,
                                 size: DynamicTypeSize = .large, minute: Int = PreviewData.minute,
                                 @ViewBuilder _ content: () -> V) throws {
        guard let directory else { return }
        let view = content()
            .padding(20)
            .frame(width: width)
            .background(Color.ground)
            .previewEnvironment(minute: minute)
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.dynamicTypeSize, size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        let data = try #require(renderer.uiImage?.pngData())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("\(name).png"))
    }

    private var engine: TideEngine { TideEngine(profile: .standard) }

    private func placeSections(_ place: Place, minute: Int = PreviewData.minute) -> some View {
        let narrative = TideNarrative(engine: engine)
        let status = engine.status(of: place, atMinute: minute)
        return VStack(alignment: .leading, spacing: 24) {
            StatusBanner(status: status, title: narrative.bannerTitle(for: status), detail: narrative.bannerDetail(for: place, atMinute: minute))
            TideChartCard(place: place, engine: engine, minute: minute, weekday: "Friday")
            HowItFeelsCard(place: place, engine: engine, minute: minute)
            GoodToKnowCard(place: place)
        }
    }

    @Test func placeSectionsForEveryPlace() throws {
        for place in PreviewData.places {
            try render("place-\(place.id)") { placeSections(place) }
        }
    }

    @Test func placeSectionsDarkAndLarge() throws {
        try render("place-marlow-dark", dark: true) { placeSections(PreviewData.library) }
        try render("place-marlow-ax3", size: .accessibility3) { placeSections(PreviewData.library) }
        try render("place-harbour-closed", minute: 20 * 60) {
            placeSections(PreviewData.places.first { $0.id == "harbour-tea-room" } ?? PreviewData.library, minute: 20 * 60)
        }
    }

    @Test func components() throws {
        try render("components") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(TideStatus.allCases, id: \.self) { StatusBadge(status: $0, size: 44) }
                    ClosedBadge(size: 44)
                }
                StatusLegend()
                Button("Find low water") {}.buttonStyle(PrimaryButtonStyle())
                Button("How's the tide?") {}.buttonStyle(OutlinedButtonStyle())
                FlowLayout {
                    ForEach(NoticedTrigger.allCases) { Chip($0.label, isSelected: $0 == .chatter, unselectedFill: .ground) {} }
                }
                BreathingCircle().frame(maxWidth: .infinity).background(Color.lowWaterBackground)
            }
        }
    }
}
