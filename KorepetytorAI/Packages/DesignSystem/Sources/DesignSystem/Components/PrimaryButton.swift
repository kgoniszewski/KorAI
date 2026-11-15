import SwiftUI

/// Styl głównego przycisku: pełna szerokość, gradient akcentu, duże zaokrąglenie.
/// Działa też z `NavigationLink`.
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.accentForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
            .padding(.horizontal, Spacing.xl)
            .background(Palette.accentGradient, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }
}

/// Główny przycisk ekranu (jeden na ekran, prowadzi do jednej czynności).
public struct PrimaryButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let action: () -> Void

    public init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

#Preview("Jasny") {
    VStack(spacing: Spacing.l) {
        PrimaryButton("Zacznij 10 minut", systemImage: "play.fill") {}
        PrimaryButton("Wyłączony") {}
            .disabled(true)
    }
    .padding(Spacing.xl)
    .background(Palette.background)
}

#Preview("Ciemny, największy tekst") {
    PrimaryButton("Zacznij 10 minut", systemImage: "play.fill") {}
        .padding(Spacing.xl)
        .background(Palette.background)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility5)
}
