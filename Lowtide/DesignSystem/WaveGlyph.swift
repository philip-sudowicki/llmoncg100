import SwiftUI

/// One, two or three small horizontal waves. Calm uses one, Busy two and High tide three,
/// so a status never relies on colour alone.
struct WaveGlyph: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        let waves = min(max(count, 1), 3)
        let amplitude: CGFloat
        let spacing: CGFloat
        switch waves {
        case 1:
            amplitude = rect.height * 0.16
            spacing = 0
        case 2:
            amplitude = rect.height * 0.11
            spacing = rect.height * 0.36
        default:
            amplitude = rect.height * 0.09
            spacing = rect.height * 0.32
        }

        var path = Path()
        let firstY = rect.midY - spacing * CGFloat(waves - 1) / 2
        let half = rect.width / 2
        for index in 0..<waves {
            let y = firstY + spacing * CGFloat(index)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + half, y: y),
                control: CGPoint(x: rect.minX + half / 2, y: y - amplitude * 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: y),
                control: CGPoint(x: rect.minX + half * 1.5, y: y + amplitude * 2)
            )
        }
        return path
    }
}

/// The coloured status circle holding its wave glyph. A closed place shows a neutral circle with a moon.
struct StatusBadge: View {
    let status: TideStatus?
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(status?.fill ?? Color.divider)
            if let status {
                WaveGlyph(count: status.waveCount)
                    .stroke(status.onFill, style: StrokeStyle(lineWidth: max(1.3, size * 0.075), lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.56, height: size * 0.56)
            } else {
                Image(systemName: "moon.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.inkSecondary)
                    .frame(width: size * 0.46, height: size * 0.46)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A bare glyph in the status colour, for inline use next to text.
struct StatusGlyph: View {
    let status: TideStatus
    var color: Color? = nil
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 16

    var body: some View {
        WaveGlyph(count: status.waveCount)
            .stroke(color ?? status.glyphColor, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: width, height: width * 0.8)
            .accessibilityHidden(true)
    }
}

extension TideStatus {
    var fill: Color {
        switch self {
        case .calm: .calm
        case .busy: .busy
        case .high: .high
        }
    }

    /// Glyph colour drawn on `fill`.
    var onFill: Color {
        switch self {
        case .calm: .onCalm
        case .busy: .onBusy
        case .high: .onHigh
        }
    }

    /// Colour for a bare glyph drawn on `surface` or `ground`, at 3:1 or better.
    var glyphColor: Color {
        switch self {
        case .calm: .calm
        case .busy: .busyGlyph
        case .high: .high
        }
    }

    /// Soft background for banners.
    var tint: Color {
        switch self {
        case .calm: .calmTint
        case .busy: .busyTint
        case .high: .highTint
        }
    }
}

#Preview("Status glyphs") {
    VStack(alignment: .leading, spacing: 16) {
        ForEach(TideStatus.allCases) { status in
            HStack(spacing: 12) {
                StatusBadge(status: status)
                StatusBadge(status: status, size: 44)
                StatusGlyph(status: status)
                Text(status.title).foregroundStyle(.ink)
            }
        }
        HStack(spacing: 12) {
            StatusBadge(status: nil)
            StatusBadge(status: nil, size: 44)
            Text("Closed").foregroundStyle(.ink)
        }
    }
    .padding()
    .background(Color.ground)
}
