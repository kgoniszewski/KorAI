import DesignSystem
import SwiftUI

/// Nauka. W M0 ekran zastępczy; w układzie wąskim prowadzi też do Korepetytora.
struct StudyView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScreenContainer(title: "section.study") {
            EmptyState(
                "study.empty.title",
                message: "study.empty.message",
                systemImage: "brain.head.profile",
                tint: SubjectPalette.violet.color
            ) {
                // Na iPadzie Korepetytor ma własną pozycję w pasku bocznym.
                if horizontalSizeClass != .regular {
                    NavigationLink {
                        TutorView()
                    } label: {
                        Label("study.openTutor", systemImage: "text.bubble.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
}

#Preview {
    NavigationStack { StudyView() }
}
