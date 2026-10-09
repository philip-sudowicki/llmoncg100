import SwiftUI

/// A white rounded card with a hairline border, the basic container on grouped screens.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.divider, lineWidth: contrast == .increased ? 1.5 : 1)
            )
    }
}

/// A 44 pt rounded tile holding an SF Symbol, used at the start of list rows.
struct IconTile: View {
    let systemImage: String
    var foreground: Color = .calmDeep
    var background: Color = .calmTint

    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A hairline in the `divider` colour.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

/// Small uppercase section title, as used on the Tide profile.
struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.inkSecondary)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Five short bars showing an intensity from 1 to 5.
struct StepMeter: View {
    let level: Int
    var steps = 5
    var tint: Color = .calm

    @ScaledMetric(relativeTo: .body) private var barWidth: CGFloat = 6
    @ScaledMetric(relativeTo: .body) private var barHeight: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<steps, id: \.self) { index in
                Capsule()
                    .fill(index < level ? tint : Color.divider)
                    .frame(width: barWidth, height: barHeight)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(min(max(level, 0), steps)) out of \(steps)")
    }
}

/// A tiny tide curve of today for list rows, with a dot at the current time.
struct TideSparkline: View {
    let points: [TidePoint]
    var now: Int?

    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            guard let first = points.first, let last = points.last, last.minute > first.minute else { return }
            let top = max(1.0, points.map(\.score).max() ?? 1)
            func position(minute: Double, score: Double) -> CGPoint {
                let x = (minute - Double(first.minute)) / Double(last.minute - first.minute) * size.width
                let y = size.height - 2 - CGFloat(min(score, top) / top) * (size.height - 4)
                return CGPoint(x: x, y: y)
            }
            var line = Path()
            for (index, point) in points.enumerated() {
                let location = position(minute: Double(point.minute), score: point.score)
                if index == 0 {
                    line.move(to: location)
                } else {
                    let previous = position(minute: Double(points[index - 1].minute), score: points[index - 1].score)
                    let midX = (previous.x + location.x) / 2
                    line.addCurve(to: location, control1: CGPoint(x: midX, y: previous.y), control2: CGPoint(x: midX, y: location.y))
                }
            }
            context.stroke(line, with: .color(.calm), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

            if let now, now >= first.minute, now <= last.minute,
               let after = points.firstIndex(where: { $0.minute >= now }) {
                let upper = points[after]
                let lower = after > 0 ? points[after - 1] : upper
                let span = Double(upper.minute - lower.minute)
                let fraction = span > 0 ? Double(now - lower.minute) / span : 0
                let score = lower.score + (upper.score - lower.score) * fraction
                let dot = position(minute: Double(now), score: score)
                context.fill(Path(ellipseIn: CGRect(x: dot.x - 3.5, y: dot.y - 3.5, width: 7, height: 7)), with: .color(.calm))
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }
}

#Preview("Cards") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "What gets to you")
            Card {
                HStack(spacing: 12) {
                    IconTile(systemImage: "books.vertical")
                    VStack(alignment: .leading) {
                        Text("Marlow Street Library").font(.headline).foregroundStyle(.ink)
                        Text("Calm until 3:30pm · 3 min walk").font(.subheadline).foregroundStyle(.inkSecondary)
                    }
                    Spacer()
                    TideSparkline(
                        points: [0.2, 0.5, 0.6, 0.3, 0.25, 0.55, 0.35].enumerated().map {
                            TidePoint(minute: 540 + $0.offset * 90, score: $0.element)
                        },
                        now: 840
                    )
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Noise").foregroundStyle(.ink); Spacer(); StepMeter(level: 2) }
                    Hairline()
                    HStack { Text("Crowds").foregroundStyle(.ink); Spacer(); StepMeter(level: 4) }
                }
            }
        }
        .padding()
    }
    .background(Color.ground)
}
