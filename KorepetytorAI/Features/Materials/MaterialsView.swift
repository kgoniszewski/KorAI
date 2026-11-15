import DesignSystem
import SwiftUI

/// Materiały. W M0 ekran zastępczy; notatki, zdjęcia i PDF powstają w M2.
struct MaterialsView: View {
    var body: some View {
        ScreenContainer(title: "section.materials") {
            EmptyState(
                "materials.empty.title",
                message: "materials.empty.message",
                systemImage: "folder.fill",
                tint: SubjectPalette.emerald.color
            )
        }
    }
}

#Preview {
    NavigationStack { MaterialsView() }
}
