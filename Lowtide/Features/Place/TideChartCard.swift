import Charts
import SwiftUI

/// "Today's tide": the personal score through opening hours. Lower is calmer, like a tide.
struct TideChartCard: View {
    let place: Place
    let engine: TideEngine
    let minute: Int
    let weekday: String

    private var narrative: TideNarrative { TideNarrative(engine: engine) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Today's tide") {
                Text("\(weekday) · for you")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(Color.calm)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(narrative.bestTimeLine(for: place, atMinute: minute))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                }

                TideChart(
                    points: engine.series(for: place),
                    hours: place.hours,
                    now: place.hours.isOpen(atMinute: minute) ? minute : nil,
                    nowScore: engine.score(of: place, atMinute: minute),
                    best: engine.bestWindow(for: place, atMinute: minute),
                    summary: narrative.chartSummary(for: place, atMinute: minute)
                )
                .frame(height: 170)
                // Room for the "Now" label above the plot.
                .padding(.top, 16)

                FlowLayout(spacing: 14, lineSpacing: 6) {
                    LegendItem(title: "Tide level") {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.calm.opacity(0.18))
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.calm, lineWidth: 1.5))
                            .frame(width: 16, height: 11)
                    }
                    LegendItem(title: "Busy for you") {
                        Rectangle()
                            .stroke(Color.busy, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                            .frame(width: 16, height: 0.5)
                    }
                    LegendItem(title: "Best time") {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.calm.opacity(0.2))
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityHidden(true)

                Text(narrative.takeaway(for: place))
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
            }
            .card()
        }
    }
}

private struct LegendItem<Swatch: View>: View {
    let title: String
    @ViewBuilder var swatch: Swatch

    var body: some View {
        HStack(spacing: 6) {
            swatch
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
        }
    }
}

struct TideChart: View {
    let points: [TidePoint]
    let hours: OpeningHours
    let now: Int?
    let nowScore: Double
    let best: TimeWindow?
    let summary: String

    private var axisMinutes: [Int] {
        let first = ((hours.open + 179) / 180) * 180
        return Array(stride(from: first, through: hours.close, by: 180))
    }

    /// Scores above 1 are drawn at the top of the chart.
    private func plotted(_ score: Double) -> Double {
        min(max(score, 0), 1)
    }

    var body: some View {
        Chart {
            if let best {
                RectangleMark(
                    xStart: .value("Best start", best.start),
                    xEnd: .value("Best end", best.end)
                )
                .foregroundStyle(Color.calm.opacity(0.12))
            }

            ForEach(points) { point in
                AreaMark(
                    x: .value("Time", point.minute),
                    y: .value("Tide", plotted(point.score))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.calm.opacity(0.16))

                LineMark(
                    x: .value("Time", point.minute),
                    y: .value("Tide", plotted(point.score))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.calm)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }

            RuleMark(y: .value("Busy for you", TideEngine.calmThreshold))
                .foregroundStyle(Color.busy)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Busy for you")
                        .font(.caption2)
                        .foregroundStyle(Color.busyText)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Color.surface.opacity(0.9)))
                }

            if let now {
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(Color.ink.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top) {
                        Text("Now")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.ink)
                    }
                PointMark(
                    x: .value("Now", now),
                    y: .value("Tide", plotted(nowScore))
                )
                .foregroundStyle(Color.calmDeep)
                .symbolSize(70)
            }
        }
        .chartXScale(domain: hours.open...hours.close)
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: axisMinutes) { value in
                AxisGridLine()
                    .foregroundStyle(Color.divider)
                AxisValueLabel {
                    if let minute = value.as(Int.self) {
                        Text(TimeText.time(minute))
                            .font(.caption2)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's tide for you")
        .accessibilityValue(summary)
    }
}

#Preview("Today's tide") {
    ScrollView {
        TideChartCard(
            place: PreviewData.library,
            engine: TideEngine(profile: .standard),
            minute: PreviewData.minute,
            weekday: "Friday"
        )
        .padding()
    }
    .background(Color.ground)
}
