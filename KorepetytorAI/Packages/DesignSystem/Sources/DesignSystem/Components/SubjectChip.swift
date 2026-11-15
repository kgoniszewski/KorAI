import SwiftUI

/// Etykieta przedmiotu: ikona w kolorze przedmiotu na lekko zabarwionym tle.
/// Tekst ma kolor podstawowy, więc pozostaje czytelny także przy jasnych kolorach palety.
public struct SubjectChip: View {
    private let name: String
    private let colorName: String
    private let iconName: String

    public init(name: String, colorName: String, iconName: String) {
        self.name = name
        self.colorName = colorName
        self.iconName = iconName
    }

    public var body: some View {
        let tint = SubjectPalette.color(named: colorName)
        Label {
            Text(name)
                .foregroundStyle(Palette.textPrimary)
        } icon: {
            Image(systemName: iconName)
                .foregroundStyle(tint)
        }
        .font(Typography.callout.weight(.semibold))
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Jasny") {
    VStack(alignment: .leading, spacing: Spacing.s) {
        SubjectChip(name: "Biologia", colorName: "emerald", iconName: "leaf.fill")
        SubjectChip(name: "Historia", colorName: "sunflower", iconName: "building.columns.fill")
        SubjectChip(name: "Usługi żywieniowe", colorName: "cocoa", iconName: "fork.knife")
    }
    .padding(Spacing.xl)
    .background(Palette.background)
}

#Preview("Ciemny, największy tekst") {
    SubjectChip(name: "Organizacja pracy w hotelarstwie", colorName: "tangerine", iconName: "list.bullet.clipboard.fill")
        .padding(Spacing.xl)
        .background(Palette.background)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility5)
}
