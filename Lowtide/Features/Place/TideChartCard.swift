import Accessibility
import Charts
import SwiftUI

/// "Today's tide": the user's personal score through opening hours. Lower is calmer, so the
/// curve reads like a tide, with a dashed line where it turns busy for this user.
struct TideChartCard: View {
    let place: Place
    let engine: TideEngine
    let minute: Int

    var body: some View {
        let hours = place.hours
        let curve = engine.curve(for: place, step: 30)
        let isOpen = hours.isOpen(at: minute)
        let best = engine.bestWindow(for: place, from: max(minute, hours.opens))
        let top = max(1.0, (curve.map(\.score).max() ?? 1) * 1.1)
        let nowScore = engine.score(of: place, at: Double(minute))
        let bestText = minute >= hours.closes
            ? "Closed for today"
            : TideText.bestTime(best, now: minute, closes: hours.closes)
        let takeaway = TideText.takeaway(engine.takeaway(for: place))

        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle()
                        .fill(Color.calm)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(bestText)
                        .font(.headline)
                        .foregroundStyle(.ink)
                }

                Chart {
                    if let best {
                        RectangleMark(
                            xStart: .value("Best time starts", best.start),
                            xEnd: .value("Best time ends", best.end),
                            yStart: .value("Bottom", 0.0),
                            yEnd: .value("Top", top)
                        )
                        .foregroundStyle(Color.calm.opacity(0.12))
                    }

                    ForEach(curve) { point in
                        AreaMark(
                            x: .value("Time", point.minute),
                            y: .value("Tide", min(point.score, top))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.calm.opacity(0.16))

                        LineMark(
                            x: .value("Time", point.minute),
                            y: .value("Tide", min(point.score, top))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.calm)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }

                    RuleMark(y: .value("Busy for you", TideEngine.calmLimit))
                        .foregroundStyle(Color.busy)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .top, alignment: .trailing, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            Text("Busy for you")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.busyText)
                        }

                    if isOpen {
                        RuleMark(x: .value("Now", minute))
                            .foregroundStyle(Color.ink.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                Text("Now")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.ink)
                            }
                        PointMark(
                            x: .value("Now", minute),
                            y: .value("Tide", min(nowScore, top))
                        )
                        .foregroundStyle(Color.ink)
                        .symbolSize(50)
                    }
                }
                .chartXScale(domain: hours.opens...hours.closes)
                .chartYScale(domain: 0...top)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: Self.ticks(for: hours)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.divider)
                        AxisValueLabel {
                            if let tick = value.as(Int.self) {
                                Text(TideText.clock(tick))
                                    .foregroundStyle(.inkSecondary)
                            }
                        }
                    }
                }
                .frame(height: 170)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Today's tide for you")
                .accessibilityValue(summary(curve: curve, bestText: bestText, takeaway: takeaway, isOpen: isOpen, nowScore: nowScore))
                .accessibilityChartDescriptor(
                    TideChartDescriptor(points: curve, opens: hours.opens, closes: hours.closes, top: top, summary: takeaway)
                )

                ChartKey()

                Text(takeaway)
                    .font(.subheadline)
                    .foregroundStyle(.inkSecondary)
            }
        }
    }

    /// One tick every three hours, starting on the first whole hour after opening.
    static func ticks(for hours: OpeningHours) -> [Int] {
        let first = Int((Double(hours.opens) / 60).rounded(.up)) * 60
        return Array(stride(from: first, through: hours.closes, by: 180))
    }

    private func summary(curve: [TidePoint], bestText: String, takeaway: String, isOpen: Bool, nowScore: Double) -> String {
        var parts: [String] = []
        if isOpen {
            parts.append("Now: \(TideEngine.status(forScore: nowScore).title)")
        }
        parts.append(bestText)
        if let busiest = curve.max(by: { $0.score < $1.score }), busiest.score >= TideEngine.calmLimit {
            parts.append("Busiest around \(TideText.clock(busiest.minute))")
        }
        parts.append(takeaway)
        return parts.joined(separator: ". ") + "."
    }
}

/// The key under the chart: tide level, busy line and best time.
private struct ChartKey: View {
    var body: some View {
        FlowLayout(spacing: 16, lineSpacing: 6) {
            key(swatch: RoundedRectangle(cornerRadius: 3).fill(Color.calm.opacity(0.16)).overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.calm, lineWidth: 1.5)), title: "Tide level")
            key(swatch: Rectangle().fill(Color.clear).overlay(Rectangle().stroke(Color.busy, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(height: 1.5)), title: "Busy for you")
            key(swatch: RoundedRectangle(cornerRadius: 3).fill(Color.calm.opacity(0.18)), title: "Best time")
        }
        .accessibilityHidden(true)
    }

    private func key(swatch: some View, title: String) -> some View {
        HStack(spacing: 6) {
            swatch.frame(width: 16, height: 12)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.ink)
        }
    }
}

/// Audio Graph support for VoiceOver users.
struct TideChartDescriptor: AXChartDescriptorRepresentable {
    let points: [TidePoint]
    let opens: Int
    let closes: Int
    let top: Double
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Time of day",
            range: Double(opens)...Double(closes),
            gridlinePositions: [],
            valueDescriptionProvider: { TideText.clock(Int($0)) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Tide for you",
            range: 0...top,
            gridlinePositions: [TideEngine.calmLimit, TideEngine.highLimit],
            valueDescriptionProvider: { TideEngine.status(forScore: $0).title }
        )
        let series = AXDataSeriesDescriptor(
            name: "Tide",
            isContinuous: true,
            dataPoints: points.map { AXDataPoint(x: Double($0.minute), y: $0.score) }
        )
        return AXChartDescriptor(
            title: "Today's tide",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Tide chart") {
    ScrollView {
        TideChartCard(
            place: PreviewSupport.place(),
            engine: TideEngine(profile: PreviewSupport.mockupProfile),
            minute: 14 * 60
        )
        .padding()
    }
    .background(Color.ground)
}
