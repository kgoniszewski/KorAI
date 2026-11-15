import SwiftUI

/// Karta: zaokrąglona powierzchnia z miękkim cieniem.
public struct Card<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

#Preview("Jasny") {
    Card {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Kartkówka z biologii")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("Jutro · Komórka roślinna")
                .font(Typography.callout)
                .foregroundStyle(Palette.textSecondary)
        }
    }
    .padding(Spacing.xl)
    .background(Palette.background)
}

#Preview("Ciemny, największy tekst") {
    Card {
        Text("Kartkówka z biologii")
            .font(Typography.headline)
            .foregroundStyle(Palette.textPrimary)
    }
    .padding(Spacing.xl)
    .background(Palette.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
