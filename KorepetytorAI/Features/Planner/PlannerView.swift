import DesignSystem
import SwiftUI

/// Planer. Kalendarz powstaje w kolejnych krokach M1; na razie wejście do listy przedmiotów.
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SubjectListView()
                } label: {
                    Label("subjects.title", systemImage: "books.vertical.fill")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { PlannerView() }
        .modelContainer(PreviewSupport.container)
}
