import SwiftUI

/// Ekran zastępczy: duża ikona, tytuł, opis i opcjonalne akcje.
/// Nie ma stałych wysokości, więc przy największym rozmiarze tekstu tylko rośnie
/// (umieszczaj go w `ScrollView` lub `List`).
public struct EmptyState<Actions: View>: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let systemImage: String
    private let tint: Color
    private let actions: Actions

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 52

    public init(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String,
        tint: Color = Palette.accent,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: systemImage)
                .font(.system(size: min(iconSize, 96), weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .padding(Spacing.xl)
                .background(tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: Spacing.s) {
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            actions
        }
        .padding(Spacing.xl)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyState where Actions == EmptyView {
    public init(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey,
        systemImage: String,
        tint: Color = Palette.accent
    ) {
        self.init(title, message: message, systemImage: systemImage, tint: tint) { EmptyView() }
    }
}

#Preview("Jasny") {
    ScrollView {
        EmptyState(
            "Kalendarz jest jeszcze pusty",
            message: "Wkrótce dodasz tu kartkówki, sprawdziany i prace klasowe.",
            systemImage: "calendar"
        ) {
            PrimaryButton("Dodaj termin", systemImage: "plus") {}
        }
    }
    .background(Palette.background)
}

#Preview("Ciemny, największy tekst") {
    ScrollView {
        EmptyState(
            "Kalendarz jest jeszcze pusty",
            message: "Wkrótce dodasz tu kartkówki, sprawdziany i prace klasowe.",
            systemImage: "calendar",
            tint: SubjectPalette.sky.color
        )
    }
    .background(Palette.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
