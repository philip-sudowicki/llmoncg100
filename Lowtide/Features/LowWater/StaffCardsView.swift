import SwiftUI

/// Very large, high-contrast messages to show to staff. Swipe between them.
struct StaffCardsView: View {
    static let messages = [
        "I need a quiet moment",
        "Could the music go down a little?",
        "I'm autistic and need a minute. I'm okay.",
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(Self.messages.enumerated()), id: \.offset) { index, message in
                Text(message)
                    .font(.largeTitle.bold())
                    // Text styles only: the card always uses at least an accessibility size.
                    .dynamicTypeSize(DynamicTypeSize.accessibility2...DynamicTypeSize.accessibility5)
                    .minimumScaleFactor(0.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 80)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
                    .accessibilityLabel(message)
                    .accessibilityHint("Card \(index + 1) of \(Self.messages.count). Swipe to change the card.")
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color.lowWaterBackground.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.lowWaterText)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.lowWaterCard))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(20)
            .accessibilityLabel("Close")
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }
}

#Preview("Staff cards") {
    StaffCardsView()
}
