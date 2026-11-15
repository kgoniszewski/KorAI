import DesignSystem
import SwiftUI

/// Korepetytor. W M0 ekran zastępczy; czat powstaje w M5.
struct TutorView: View {
    var body: some View {
        ScreenContainer(title: "section.tutor") {
            EmptyState(
                "tutor.empty.title",
                message: "tutor.empty.message",
                systemImage: "text.bubble.fill",
                tint: SubjectPalette.indigo.color
            )
        }
    }
}

#Preview {
    NavigationStack { TutorView() }
}
