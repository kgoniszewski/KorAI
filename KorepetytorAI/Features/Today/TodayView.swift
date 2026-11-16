import Core
import DesignSystem
import SwiftData
import SwiftUI

/// Ekran Dziś: powitanie, najbliższe terminy i miejsce na zadania z planu nauki (M5).
struct TodayView: View {
    /// Liczba najbliższych terminów na ekranie.
    static let upcomingLimit = 3

    @Query(sort: [SortDescriptor(\Profile.createdAt)])
    private var profiles: [Profile]

    @Query(sort: [SortDescriptor(\Assessment.date), SortDescriptor(\Assessment.createdAt)])
    private var assessments: [Assessment]

    @State private var editorTarget: AssessmentEditorTarget?

    /// Nadchodzące od początku dzisiejszego dnia (tak jak `AssessmentRepository.upcoming`).
    private var upcoming: [Assessment] {
        let today = Calendar.current.startOfDay(for: .now)
        return Array(
            assessments
                .filter { $0.status == .upcoming && $0.date >= today }
                .prefix(Self.upcomingLimit)
        )
    }

    var body: some View {
        ScreenContainer(title: "section.today") {
            greeting
            upcomingSection
            tasksSection
        }
        .sheet(item: $editorTarget) { target in
            AssessmentEditorView(target: target)
        }
    }

    // MARK: - Sekcje

    @ViewBuilder
    private var greeting: some View {
        if let profile = profiles.first {
            HStack(spacing: Spacing.l) {
                AvatarView(avatarID: profile.avatarID, size: 56)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("today.greeting \(profile.nickname)")
                        .font(Typography.title)
                        .foregroundStyle(Palette.textPrimary)
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        let items = upcoming
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionHeader("today.upcoming.title")

            if items.isEmpty {
                Card {
                    EmptyState(
                        "today.upcoming.empty.title",
                        message: "today.upcoming.empty.message",
                        systemImage: "calendar.badge.plus",
                        tint: SubjectPalette.sky.color
                    ) {
                        PrimaryButton("today.addAssessment", systemImage: "plus") {
                            editorTarget = .new()
                        }
                    }
                }
            } else {
                ForEach(items) { assessment in
                    Button {
                        editorTarget = .edit(assessment)
                    } label: {
                        Card {
                            AssessmentRow(assessment: assessment, showsDate: true)
                        }
                    }
                    .buttonStyle(.plain)
                }
                PrimaryButton("today.addAssessment", systemImage: "plus") {
                    editorTarget = .new()
                }
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionHeader("today.tasks.title")
            Card {
                EmptyState(
                    "today.tasks.empty.title",
                    message: "today.tasks.empty.message",
                    systemImage: "checklist",
                    tint: SubjectPalette.tangerine.color
                )
            }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(Typography.headline)
            .foregroundStyle(Palette.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack { TodayView() }
        .modelContainer(PreviewSupport.container)
}
