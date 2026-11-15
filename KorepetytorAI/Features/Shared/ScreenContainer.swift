import DesignSystem
import SwiftUI

/// Wspólna oprawa ekranów modułów: przewijana zawartość na tle aplikacji.
struct ScreenContainer<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                content
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle(title)
    }
}
