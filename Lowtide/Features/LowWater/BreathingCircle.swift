import SwiftUI

/// A circle that slowly expands and contracts on a ten-second cycle: five seconds in, five out.
///
/// This is the only motion in the app. With Reduce Motion on, the circle stays still.
struct BreathingCircle: View {
    static let cycle: TimeInterval = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 200

    var body: some View {
        let diameter = min(size, 300)
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.cycle) / Self.cycle
            let inhaling = phase < 0.5
            // 0 at the start of a breath in, 1 at the top, back to 0 at the end of the breath out.
            let expansion = reduceMotion ? 0.6 : (1 - cos(phase * 2 * .pi)) / 2

            ZStack {
                Circle()
                    .stroke(Color.lowWaterAccent.opacity(0.3), lineWidth: 1)
                    .frame(width: diameter, height: diameter)
                Circle()
                    .fill(Color.lowWaterCard)
                    .frame(width: diameter * 0.82, height: diameter * 0.82)
                Circle()
                    .fill(Color.lowWaterBreath)
                    .frame(
                        width: diameter * (0.5 + 0.28 * expansion),
                        height: diameter * (0.5 + 0.28 * expansion)
                    )
                VStack(spacing: 2) {
                    Text(reduceMotion ? "Breathe" : (inhaling ? "Breathe in" : "Breathe out"))
                        .font(.headline)
                    Text("slowly")
                        .font(.subheadline)
                }
                .foregroundStyle(Color.lowWaterText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(width: diameter * 0.48)
            }
            .frame(width: diameter, height: diameter)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Breathing guide")
        .accessibilityValue("Breathe in slowly for five seconds, then out for five seconds.")
    }
}

#Preview("Breathing") {
    BreathingCircle()
        .padding(40)
        .background(Color.lowWaterBackground)
}
