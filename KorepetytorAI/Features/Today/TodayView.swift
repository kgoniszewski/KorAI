import DesignSystem
import SwiftUI

/// Ekran Dziś. W M0 ekran zastępczy; treść powstaje w M1.
struct TodayView: View {
    var body: some View {
        ScreenContainer(title: "section.today") {
            EmptyState(
                "today.empty.title",
                message: "today.empty.message",
                systemImage: "sun.max.fill",
                tint: SubjectPalette.tangerine.color
            )
        }
    }
}

#Preview {
    NavigationStack { TodayView() }
}
