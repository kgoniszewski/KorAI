import DesignSystem
import SwiftUI

/// Planer. W M0 ekran zastępczy; kalendarz powstaje w M1.
struct PlannerView: View {
    var body: some View {
        ScreenContainer(title: "section.planner") {
            EmptyState(
                "planner.empty.title",
                message: "planner.empty.message",
                systemImage: "calendar",
                tint: SubjectPalette.sky.color
            )
        }
    }
}

#Preview {
    NavigationStack { PlannerView() }
}
