import Core
import DesignSystem
import SwiftData
import SwiftUI

/// Planer: kartkówki, sprawdziany i prace klasowe w widoku listy, z filtrem po przedmiocie.
struct PlannerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Subject.sortOrder), SortDescriptor(\Subject.name)])
    private var subjects: [Subject]

    @Query(sort: [SortDescriptor(\Assessment.date), SortDescriptor(\Assessment.createdAt)])
    private var assessments: [Assessment]

    @State private var subjectFilterID: UUID?
    @State private var editorTarget: AssessmentEditorTarget?
    @State private var pendingDeletion: Assessment?
    @State private var errorText: String?

    /// Sprawdziany po filtrze przedmiotu.
    private var filteredAssessments: [Assessment] {
        guard let subjectFilterID else { return assessments }
        return assessments.filter { $0.subject?.id == subjectFilterID }
    }

    private var filterSubject: Subject? {
        subjects.first { $0.id == subjectFilterID }
    }

    var body: some View {
        content
            .background(Palette.background)
            .navigationTitle("section.planner")
            .toolbar { toolbar }
            .sheet(item: $editorTarget) { target in
                AssessmentEditorView(target: target)
            }
            .confirmationDialog(
                "assessment.delete.confirm",
                isPresented: $pendingDeletion.isPresent(),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { assessment in
                Button("assessment.delete", role: .destructive) {
                    delete(assessment)
                }
                Button("common.cancel", role: .cancel) {}
            }
            .alert("common.error", isPresented: $errorText.isPresent()) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(verbatim: errorText ?? "")
            }
            .onChange(of: subjects.map(\.id)) { _, ids in
                // Przedmiot z filtra mógł zostać usunięty lub scalony.
                if let subjectFilterID, !ids.contains(subjectFilterID) {
                    self.subjectFilterID = nil
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if filteredAssessments.isEmpty {
            ScrollView {
                emptyState
                    .padding(Spacing.l)
            }
        } else {
            AssessmentListView(
                assessments: filteredAssessments,
                onSelect: { editorTarget = .edit($0) },
                onComplete: markCompleted,
                onDelete: { pendingDeletion = $0 }
            )
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let filterSubject {
            EmptyState(
                "planner.empty.filtered.title",
                message: "planner.empty.filtered.message \(filterSubject.name)",
                systemImage: "line.3.horizontal.decrease.circle",
                tint: SubjectPalette.color(named: filterSubject.colorName)
            ) {
                PrimaryButton("planner.addAssessment", systemImage: "plus") {
                    editorTarget = .new(subjectID: filterSubject.id)
                }
            }
        } else {
            EmptyState(
                "planner.empty.title",
                message: "planner.empty.message",
                systemImage: "calendar",
                tint: SubjectPalette.sky.color
            ) {
                PrimaryButton("planner.addAssessment", systemImage: "plus") {
                    editorTarget = .new()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink {
                SubjectListView()
            } label: {
                Label("subjects.title", systemImage: "books.vertical.fill")
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("planner.filter", selection: $subjectFilterID) {
                    Label("planner.filter.all", systemImage: "square.grid.2x2").tag(UUID?.none)
                    ForEach(subjects) { subject in
                        Label {
                            Text(verbatim: subject.name)
                        } icon: {
                            Image(systemName: subject.iconName)
                        }
                        .tag(Optional(subject.id))
                    }
                }
            } label: {
                Label(
                    "planner.filter",
                    systemImage: subjectFilterID == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
            }
            .accessibilityValue(filterSubject.map { Text(verbatim: $0.name) } ?? Text("planner.filter.all"))

            Button("planner.addAssessment", systemImage: "plus") {
                editorTarget = .new(subjectID: subjectFilterID)
            }
        }
    }

    // MARK: - Akcje

    private func markCompleted(_ assessment: Assessment) {
        do {
            try AssessmentRepository(context: modelContext).markCompleted(assessment, grade: assessment.grade)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete(_ assessment: Assessment) {
        do {
            try AssessmentRepository(context: modelContext).delete(assessment)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// Lista sprawdzianów pogrupowana po dniu: najpierw dziś i przyszłe (od najbliższego),
/// potem minione (od najnowszego).
struct AssessmentListView: View {
    let assessments: [Assessment]
    let onSelect: (Assessment) -> Void
    let onComplete: (Assessment) -> Void
    let onDelete: (Assessment) -> Void

    var body: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let groups = PlannerCalendar.groupedByDay(assessments) { $0.date }
        let upcoming = groups.filter { $0.day >= today }
        let past = Array(groups.filter { $0.day < today }.reversed())

        List {
            ForEach(upcoming) { group in
                daySection(day: group.day, items: group.items, isPast: false)
            }
            ForEach(past) { group in
                daySection(day: group.day, items: group.items, isPast: true)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func daySection(day: Date, items: [Assessment], isPast: Bool) -> some View {
        Section {
            ForEach(items) { assessment in
                AssessmentListRow(
                    assessment: assessment,
                    onSelect: onSelect,
                    onComplete: onComplete,
                    onDelete: onDelete
                )
            }
        } header: {
            if isPast {
                Text("planner.list.pastHeader \(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))")
            } else {
                Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
            }
        }
    }
}

/// Wiersz listy z gestami: w prawo — zakończ, w lewo — usuń (z potwierdzeniem).
struct AssessmentListRow: View {
    let assessment: Assessment
    let onSelect: (Assessment) -> Void
    let onComplete: (Assessment) -> Void
    let onDelete: (Assessment) -> Void

    var body: some View {
        Button {
            onSelect(assessment)
        } label: {
            AssessmentRow(assessment: assessment)
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if assessment.status == .upcoming {
                Button("assessment.markCompleted", systemImage: "checkmark") {
                    onComplete(assessment)
                }
                .tint(SubjectPalette.emerald.color)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Bez roli `.destructive`: wiersz znika dopiero po potwierdzeniu.
            Button("assessment.delete", systemImage: "trash") {
                onDelete(assessment)
            }
            .tint(SubjectPalette.rose.color)
        }
    }
}

#Preview {
    NavigationStack { PlannerView() }
        .modelContainer(PreviewSupport.container)
}
