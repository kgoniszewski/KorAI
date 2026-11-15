import DesignSystem
import SwiftUI

/// Moduły widoczne w nawigacji.
enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case today
    case planner
    case materials
    case study
    case tutor
    case profile

    var id: String { rawValue }

    /// Pięć zakładek w układzie wąskim (iPhone, wąski Split View na iPadzie).
    static let tabs: [AppSection] = [.today, .planner, .materials, .study, .profile]

    /// Pasek boczny w układzie szerokim; Korepetytor ma tu własną pozycję.
    static let sidebar: [AppSection] = [.today, .planner, .materials, .study, .tutor, .profile]

    var title: LocalizedStringKey {
        switch self {
        case .today: "section.today"
        case .planner: "section.planner"
        case .materials: "section.materials"
        case .study: "section.study"
        case .tutor: "section.tutor"
        case .profile: "section.profile"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max.fill"
        case .planner: "calendar"
        case .materials: "folder.fill"
        case .study: "brain.head.profile"
        case .tutor: "text.bubble.fill"
        case .profile: "star.circle.fill"
        }
    }

    /// Odpowiednik w układzie wąskim: Korepetytor jest tam przyciskiem na ekranie Nauka.
    var compactEquivalent: AppSection {
        self == .tutor ? .study : self
    }

    @MainActor @ViewBuilder
    var rootView: some View {
        switch self {
        case .today: TodayView()
        case .planner: PlannerView()
        case .materials: MaterialsView()
        case .study: StudyView()
        case .tutor: TutorView()
        case .profile: ProfileView()
        }
    }
}

/// Główny układ: `TabView` w układzie wąskim, `NavigationSplitView` w szerokim.
struct AppShell: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection: AppSection = .today

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                SidebarShell(selection: $selection)
            } else {
                TabShell(selection: $selection)
            }
        }
        .tint(Palette.accent)
        .onChange(of: horizontalSizeClass) { _, newValue in
            // iPad w wąskim Split View: Korepetytora nie ma w zakładkach.
            if newValue != .regular {
                selection = selection.compactEquivalent
            }
        }
    }
}

private struct TabShell: View {
    @Binding var selection: AppSection

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.tabs) { section in
                Tab(section.title, systemImage: section.systemImage, value: section) {
                    NavigationStack {
                        section.rootView
                    }
                }
            }
        }
    }
}

private struct SidebarShell: View {
    @Binding var selection: AppSection

    var body: some View {
        let binding = $selection
        let sidebarSelection = Binding<AppSection?>(
            get: { binding.wrappedValue },
            set: { newValue in
                if let newValue {
                    binding.wrappedValue = newValue
                }
            }
        )

        NavigationSplitView {
            List(AppSection.sidebar, selection: sidebarSelection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
            .navigationTitle("app.name")
        } detail: {
            NavigationStack {
                selection.rootView
            }
            .id(selection)
        }
    }
}

#Preview("iPhone") {
    AppShell()
        .modelContainer(PreviewSupport.container)
        .environment(PreviewSupport.cloudAccount)
}
