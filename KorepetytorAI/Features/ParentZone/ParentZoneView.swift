import DesignSystem
import SwiftUI

/// Strefa rodzica. W M0 ekran zastępczy; PIN i nagrody powstają w M6.
struct ParentZoneView: View {
    var body: some View {
        ScreenContainer(title: "section.parentZone") {
            EmptyState(
                "parentZone.empty.title",
                message: "parentZone.empty.message",
                systemImage: "lock.shield.fill",
                tint: SubjectPalette.slate.color
            )
        }
    }
}

#Preview {
    NavigationStack { ParentZoneView() }
}
