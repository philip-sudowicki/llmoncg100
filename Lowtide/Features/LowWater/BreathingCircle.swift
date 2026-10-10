import SwiftUI

/// A circle that slowly grows and shrinks on a 10-second cycle: five seconds in, five out.
/// This is the only motion in the app. With Reduce Motion on, the circle stays still and only
/// the words change.
struct BreathingCircle: View {
    static let cycle: TimeInterval = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 176

    /// Grows a little with text size, but never so much that it pushes the calm place off screen.
    private var side: CGFloat { min(size, 220) }

    var body: some View {
        Group {
            if reduceMotion {
                TimelineView(.periodic(from: .now, by: Self.cycle / 2)) { context in
                    circle(scale: 0.85, inhaling: Self.isInhaling(at: context.date))
                }
            } else {
                TimelineView(.animation) { context in
                    circle(scale: Self.scale(at: context.date), inhaling: Self.isInhaling(at: context.date))
                }
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Breathing guide")
        .accessibilityValue("Breathe in slowly for five seconds, then out for five seconds.")
    }

    private func circle(scale: Double, inhaling: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(Color.lowWaterAccent.opacity(0.35), lineWidth: 1)
            Circle()
                .fill(Color.lowWaterCard)
                .padding(side * 0.1)
            Circle()
                .fill(Color.lowWaterBreath)
                .padding(side * 0.2)
                .scaleEffect(scale)
            VStack(spacing: 2) {
                Text(inhaling ? "Breathe in" : "Breathe out")
                    .font(.headline)
                Text("slowly")
                    .font(.footnote)
            }
            .foregroundStyle(.lowWaterInk)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            // The words sit inside a capped circle; VoiceOver reads the full guide from the value.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(side * 0.24)
        }
    }

    static func phase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
    }

    static func isInhaling(at date: Date) -> Bool {
        phase(at: date) < 0.5
    }

    /// Smoothly from 0.72 (empty) to 1 (full) and back, peaking halfway through the cycle.
    static func scale(at date: Date) -> Double {
        let eased = 0.5 - 0.5 * cos(2 * .pi * phase(at: date))
        return 0.72 + 0.28 * eased
    }
}

#Preview("Breathing") {
    BreathingCircle()
        .padding(40)
        .background(Color.lowWaterBackground)
}
