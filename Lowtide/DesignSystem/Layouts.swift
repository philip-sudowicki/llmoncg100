import SwiftUI

/// Lays chips out in rows, wrapping to the next row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.flatMap(\.items).map { $0.frame.maxX }.max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews: subviews, width: bounds.width) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.frame.minX, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.frame.size)
                )
            }
        }
    }

    private struct Row {
        var y: CGFloat
        var height: CGFloat = 0
        var items: [(index: Int, frame: CGRect)] = []
    }

    private func arrange(subviews: Subviews, width maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row(y: 0)
        var x: CGFloat = 0
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > maxWidth {
                // At large text sizes a chip may be wider than the row: let it wrap its text.
                size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            if x > 0, x + size.width > maxWidth {
                rows.append(row)
                row = Row(y: row.y + row.height + lineSpacing)
                x = 0
            }
            row.items.append((index, CGRect(origin: CGPoint(x: x, y: 0), size: size)))
            row.height = max(row.height, size.height)
            x += size.width + spacing
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}

/// A tiny tide curve for list rows: lower is calmer.
struct Sparkline: View {
    let points: [TidePoint]
    let domain: ClosedRange<Int>
    var now: Int?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                SparklineShape(points: normalised)
                    .stroke(Color.calm, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                if let dot = nowPoint {
                    Circle()
                        .fill(Color.calmDeep)
                        .frame(width: 6, height: 6)
                        .position(x: dot.x * size.width, y: (1 - dot.y) * size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var normalised: [CGPoint] {
        points.map { point(minute: $0.minute, score: $0.score) }
    }

    private var nowPoint: CGPoint? {
        guard let now, domain.contains(now),
              let nearest = points.min(by: { abs($0.minute - now) < abs($1.minute - now) }) else { return nil }
        return point(minute: now, score: nearest.score)
    }

    private func point(minute: Int, score: Double) -> CGPoint {
        let span = max(1, Double(domain.upperBound - domain.lowerBound))
        let x = Double(minute - domain.lowerBound) / span
        // Leave a little headroom so the line never touches the edges.
        let y = 0.1 + 0.8 * min(max(score, 0), 1)
        return CGPoint(x: x, y: y)
    }
}

/// A smooth line through normalised points (x and y from 0 to 1, y up).
struct SparklineShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mapped = points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.maxY - $0.y * rect.height) }
        guard let first = mapped.first else { return path }
        path.move(to: first)
        for (previous, next) in zip(mapped, mapped.dropFirst()) {
            let mid = CGPoint(x: (previous.x + next.x) / 2, y: (previous.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: previous)
        }
        if let last = mapped.last { path.addLine(to: last) }
        return path
    }
}

#Preview("Flow layout and sparkline") {
    VStack(alignment: .leading, spacing: 20) {
        FlowLayout {
            ForEach(NoticedTrigger.allCases) { Chip($0.label, isSelected: $0 == .chatter, unselectedFill: .ground) {} }
        }
        Sparkline(
            points: (0..<20).map { TidePoint(minute: 540 + $0 * 30, score: 0.3 + 0.25 * sin(Double($0) / 3)) },
            domain: 540...1140,
            now: 840
        )
        .frame(width: 64, height: 28)
    }
    .padding()
}
