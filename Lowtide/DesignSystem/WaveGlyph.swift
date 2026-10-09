import SwiftUI

/// One, two or three small horizontal waves: the status glyph.
///
/// Calm draws one wave, Busy two and High tide three, so status never relies on colour alone.
struct WaveGlyph: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        let waves = min(max(count, 1), 3)
        let gap = rect.height * (waves == 1 ? 0 : 0.36)
        let amplitude = rect.height * (waves == 1 ? 0.2 : 0.11)
        let firstY = rect.midY - gap * CGFloat(waves - 1) / 2
        let width = rect.width
        // A cubic control point 4/3 of the amplitude away gives a peak of exactly the amplitude.
        let lift = amplitude * 4 / 3

        var path = Path()
        for index in 0..<waves {
            let y = firstY + gap * CGFloat(index)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addCurve(
                to: CGPoint(x: rect.minX + width / 2, y: y),
                control1: CGPoint(x: rect.minX + width * 0.18, y: y - lift),
                control2: CGPoint(x: rect.minX + width * 0.32, y: y - lift)
            )
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: y),
                control1: CGPoint(x: rect.minX + width * 0.68, y: y + lift),
                control2: CGPoint(x: rect.minX + width * 0.82, y: y + lift)
            )
        }
        return path
    }
}

/// A filled circle in the status colour holding the status glyph.
struct StatusBadge: View {
    let status: TideStatus
    @ScaledMetric private var diameter: CGFloat

    init(status: TideStatus, size: CGFloat = 22) {
        self.status = status
        _diameter = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: diameter, height: diameter)
            .overlay {
                WaveGlyph(count: status.waveCount)
                    .stroke(status.onColor, style: StrokeStyle(lineWidth: max(1.4, diameter / 13), lineCap: .round))
                    .padding(diameter * 0.25)
            }
            .accessibilityHidden(true)
    }
}

/// The badge for a closed place: a muted circle with a moon.
struct ClosedBadge: View {
    @ScaledMetric private var diameter: CGFloat

    init(size: CGFloat = 22) {
        _diameter = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Circle()
            .fill(Color.ground)
            .overlay(Circle().strokeBorder(Color.divider))
            .frame(width: diameter, height: diameter)
            .overlay {
                Image(systemName: "moon.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.inkSecondary)
                    .padding(diameter * 0.27)
            }
            .accessibilityHidden(true)
    }
}

#Preview("Status glyphs") {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            ForEach(TideStatus.allCases, id: \.self) { StatusBadge(status: $0, size: 44) }
            ClosedBadge(size: 44)
        }
        HStack(spacing: 16) {
            ForEach(1...3, id: \.self) { count in
                WaveGlyph(count: count)
                    .stroke(Color.calm, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 32, height: 20)
            }
        }
    }
    .padding()
}
