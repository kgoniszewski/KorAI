import Core
import DesignSystem
import SwiftData
import SwiftUI

/// Lista przedmiotów w sekcjach „Ogólne” i „Zawodowe”: edycja, dodawanie, usuwanie.
struct SubjectListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Subject.sortOrder), SortDescriptor(\Subject.name)])
    private var subjects: [Subject]

    @State private var editorTarget: SubjectEditorTarget?
    @State private var pendingDeletion: Subject?
    @State private var blockedDeletion: BlockedDeletion?
    @State private var errorText: String?

    var body: some View {
        List {
            section(for: .general, title: "subjects.section.general")
            section(for: .vocational, title: "subjects.section.vocational")
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("subjects.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("subjects.add", systemImage: "plus") {
                    editorTarget = .new
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            switch target {
            case .new:
                SubjectEditorView(subject: nil, suggestedColorName: suggestedColorName)
            case .edit(let subject):
                SubjectEditorView(subject: subject)
            }
        }
        .confirmationDialog(
            pendingDeletion.map { Text("subjects.delete.confirm.title \($0.name)") } ?? Text(verbatim: ""),
            isPresented: $pendingDeletion.isPresent(),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { subject in
            Button("subjects.delete.confirm.action", role: .destructive) {
                delete(subject)
            }
            Button("common.cancel", role: .cancel) {}
        }
        .alert(
            blockedDeletion.map { Text("subjects.delete.blocked.title \($0.name)") } ?? Text(verbatim: ""),
            isPresented: $blockedDeletion.isPresent(),
            presenting: blockedDeletion
        ) { _ in
            Button("common.ok", role: .cancel) {}
        } message: { blocked in
            Text("subjects.delete.blocked.message \(blocked.count)")
        }
        .alert("common.error", isPresented: $errorText.isPresent()) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(verbatim: errorText ?? "")
        }
    }

    @ViewBuilder
    private func section(for kind: SubjectKind, title: LocalizedStringKey) -> some View {
        let items = subjects.filter { $0.kind == kind }
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { subject in
                    row(for: subject)
                }
            }
        }
    }

    private func row(for subject: Subject) -> some View {
        let count = subject.assessments?.count ?? 0
        return Button {
            editorTarget = .edit(subject)
        } label: {
            HStack(spacing: Spacing.m) {
                SubjectChip(name: subject.name, colorName: subject.colorName, iconName: subject.iconName)
                Spacer(minLength: Spacing.s)
                if count > 0 {
                    Text("subjects.assessmentCount \(count)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.surface)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Bez roli `.destructive`: wiersz zablokowanego przedmiotu nie może zniknąć z listy.
            Button("subjects.delete", systemImage: "trash") {
                requestDeletion(of: subject)
            }
            .tint(SubjectPalette.rose.color)
        }
    }

    /// Pierwszy kolor palety, którego nie używa jeszcze żaden przedmiot.
    private var suggestedColorName: String {
        let used = Set(subjects.map(\.colorName))
        return (SubjectPalette.allCases.first { !used.contains($0.rawValue) } ?? .slate).rawValue
    }

    private func requestDeletion(of subject: Subject) {
        let count = SubjectRepository(context: modelContext).assessmentCount(for: subject)
        if count > 0 {
            blockedDeletion = BlockedDeletion(name: subject.name, count: count)
        } else {
            pendingDeletion = subject
        }
    }

    private func delete(_ subject: Subject) {
        do {
            try SubjectRepository(context: modelContext).delete(subject)
        } catch let error as SubjectRepositoryError {
            if case .hasAssessments(let count) = error {
                blockedDeletion = BlockedDeletion(name: subject.name, count: count)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

/// Cel arkusza edytora przedmiotu.
enum SubjectEditorTarget: Identifiable {
    case new
    case edit(Subject)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let subject): subject.id.uuidString
        }
    }
}

/// Przedmiot, którego nie można usunąć, bo ma sprawdziany.
private struct BlockedDeletion {
    let name: String
    let count: Int
}

#Preview {
    NavigationStack {
        SubjectListView()
    }
    .modelContainer(PreviewSupport.container)
}
