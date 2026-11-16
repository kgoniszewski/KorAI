import Core
import DesignSystem
import SwiftData
import SwiftUI

/// Cel arkusza edytora sprawdzianu.
enum AssessmentEditorTarget: Identifiable {
    /// Nowy sprawdzian; opcjonalnie z przedmiotem (np. aktywny filtr) i dniem (np. wybrany w kalendarzu).
    case new(subjectID: UUID? = nil, date: Date? = nil)
    case edit(Assessment)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let assessment): assessment.id.uuidString
        }
    }
}

/// Szybki wpis sprawdzianu: przedmiot, rodzaj, data, zakres; przy edycji także stan i ocena.
///
/// Wszystko poza przedmiotem ma wartości domyślne, więc typowy wpis to wybór daty i „Zapisz”.
struct AssessmentEditorView: View {
    /// Klucz w `UserDefaults` z identyfikatorem ostatnio użytego przedmiotu (lokalny dla urządzenia).
    static let lastSubjectKey = "planner.lastSubjectID"

    private let assessment: Assessment?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query(sort: [SortDescriptor(\Subject.sortOrder), SortDescriptor(\Subject.name)])
    private var subjects: [Subject]

    @AppStorage(AssessmentEditorView.lastSubjectKey) private var lastSubjectID = ""

    @State private var subjectID: UUID?
    @State private var kind: AssessmentKind
    @State private var date: Date
    @State private var scope: String
    @State private var status: AssessmentStatus
    @State private var grade: String
    @State private var isConfirmingDeletion = false
    @State private var errorText: String?

    init(target: AssessmentEditorTarget) {
        switch target {
        case .new(let subjectID, let date):
            assessment = nil
            _subjectID = State(initialValue: subjectID)
            _kind = State(initialValue: .test)
            _date = State(initialValue: date ?? PlannerCalendar.defaultAssessmentDate())
            _scope = State(initialValue: "")
            _status = State(initialValue: .upcoming)
            _grade = State(initialValue: "")
        case .edit(let assessment):
            self.assessment = assessment
            _subjectID = State(initialValue: assessment.subject?.id)
            _kind = State(initialValue: assessment.kind)
            _date = State(initialValue: assessment.date)
            _scope = State(initialValue: assessment.scope)
            _status = State(initialValue: assessment.status)
            _grade = State(initialValue: assessment.grade ?? "")
        }
    }

    private var isEditing: Bool { assessment != nil }

    private var selectedSubject: Subject? {
        subjects.first { $0.id == subjectID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    subjectPicker
                    kindPicker
                    DatePicker("assessment.editor.date", selection: $date, displayedComponents: .date)
                }

                Section("assessment.editor.scope") {
                    TextField("assessment.editor.scopePlaceholder", text: $scope, axis: .vertical)
                        .lineLimit(2...6)
                }

                if isEditing {
                    Section {
                        Picker("assessment.editor.status", selection: $status) {
                            ForEach(AssessmentStatus.allCases, id: \.self) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        if status == .completed {
                            TextField("assessment.editor.gradePlaceholder", text: $grade)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    } footer: {
                        Text("assessment.editor.gradeFooter")
                    }

                    Section {
                        Button("assessment.delete", systemImage: "trash", role: .destructive) {
                            isConfirmingDeletion = true
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(isEditing ? LocalizedStringKey("assessment.editor.editTitle") : LocalizedStringKey("assessment.editor.newTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(selectedSubject == nil)
                }
            }
            .onAppear(perform: applyDefaultSubject)
            .confirmationDialog("assessment.delete.confirm", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
                Button("assessment.delete", role: .destructive, action: delete)
                Button("common.cancel", role: .cancel) {}
            }
            .alert("common.error", isPresented: $errorText.isPresent()) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(verbatim: errorText ?? "")
            }
        }
    }

    // MARK: - Pola

    private var subjectPicker: some View {
        Picker("assessment.editor.subject", selection: $subjectID) {
            if selectedSubject == nil {
                Text("assessment.editor.chooseSubject").tag(UUID?.none)
            }
            ForEach(subjects) { subject in
                Label {
                    Text(verbatim: subject.name)
                } icon: {
                    Image(systemName: subject.iconName)
                        .foregroundStyle(SubjectPalette.color(named: subject.colorName))
                }
                .tag(Optional(subject.id))
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var kindPicker: some View {
        let picker = Picker("assessment.editor.kind", selection: $kind) {
            ForEach(AssessmentKind.editorOrder, id: \.self) { kind in
                Text(kind.title).tag(kind)
            }
        }
        // Przy dużym tekście cztery segmenty się nie mieszczą.
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    // MARK: - Akcje

    /// Nowy sprawdzian bez wskazanego przedmiotu dostaje ostatnio użyty (jeśli nadal istnieje).
    private func applyDefaultSubject() {
        guard !isEditing, subjectID == nil else { return }
        if let lastID = UUID(uuidString: lastSubjectID), subjects.contains(where: { $0.id == lastID }) {
            subjectID = lastID
        }
    }

    private func save() {
        guard let subject = selectedSubject else { return }
        let repository = AssessmentRepository(context: modelContext)
        do {
            if let assessment {
                try repository.update(
                    assessment,
                    subject: subject,
                    kind: kind,
                    date: date,
                    scope: scope,
                    status: status,
                    grade: grade
                )
            } else {
                try repository.add(subject: subject, kind: kind, date: date, scope: scope)
            }
            lastSubjectID = subject.id.uuidString
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete() {
        guard let assessment else { return }
        do {
            try AssessmentRepository(context: modelContext).delete(assessment)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview("Nowy") {
    AssessmentEditorView(target: .new())
        .modelContainer(PreviewSupport.container)
}
