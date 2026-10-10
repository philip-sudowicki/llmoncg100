import SwiftUI

/// Very large, high-contrast cards the user can show to staff. Swipe between them.
struct StaffCardsView: View {
    static let cards = [
        "I need a quiet moment.",
        "Could the music go down a little?",
        "I'm autistic and need a minute. I'm okay.",
    ]

    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.surface
                .ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Self.cards.indices, id: \.self) { index in
                    Text(Self.cards[index])
                        .font(.largeTitle.bold())
                        .dynamicTypeSize(.accessibility2 ... .accessibility5)
                        .minimumScaleFactor(0.4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.ink)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 72)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Card \(index + 1) of \(Self.cards.count): \(Self.cards[index])")
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            CircleIconButton(systemImage: "xmark", label: "Close card", foreground: .ink, background: .ground) {
                dismiss()
            }
            .padding(16)
        }
        .overlay(alignment: .bottom) {
            Text("Swipe for another card")
                .font(.footnote)
                .foregroundStyle(.inkSecondary)
                .padding(.bottom, 52)
                .accessibilityHidden(true)
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }
}

#Preview("Staff cards") {
    StaffCardsView()
}
