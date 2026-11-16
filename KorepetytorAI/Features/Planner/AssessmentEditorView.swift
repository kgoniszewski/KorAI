import Core
import DesignSystem
import SwiftData
import SwiftUI
import UIKit

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
    @Environment(\.openURL) private var openURL

    @Query(sort: [SortDescriptor(\Subject.sortOrder), SortDescriptor(\Subject.name)])
    private var subjects: [Subject]

    @AppStorage(AssessmentEditorView.lastSubjectKey) private var lastSubjectID = ""

    @State private var subjectID: UUID?
    @State private var kind: AssessmentKind
    @State private var date: Date
    @State private var scope: String
    @State private var status: AssessmentStatus
    @State private var grade: String
    @State private var reminderEnabled: Bool
    @State private var authorization: ReminderScheduler.Authorization?
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
            _reminderEnabled = State(initialValue: true)
        case .edit(let assessment):
            self.assessment = assessment
            _subjectID = State(initialValue: assessment.subject?.id)
            _kind = State(initialValue: assessment.kind)
            _date = State(initialValue: assessment.date)
            _scope = State(initialValue: assessment.scope)
            _status = State(initialValue: assessment.status)
            _grade = State(initialValue: assessment.grade ?? "")
            _reminderEnabled = State(initialValue: ReminderPreferences().isEnabled(for: assessment.id))
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

                if status == .upcoming {
                    reminderSection
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
            .task {
                authorization = await ReminderScheduler.authorization()
            }
            .onChange(of: reminderEnabled) { _, isEnabled in
                // Zgoda przy pierwszym włączeniu przełącznika.
                if isEnabled, authorization == .notDetermined {
                    Task { authorization = await ReminderScheduler.requestAuthorization() }
                }
            }
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

    /// Przełącznik przypomnienia. Bez zgody na powiadomienia jest wyłączony
    /// i pokazuje, jak włączyć zgodę w Ustawieniach.
    private var reminderSection: some View {
        let isDenied = authorization == .denied
        let fireDate = ReminderPlanner.reminderDate(assessmentDate: date, status: .upcoming)

        return Section {
            if isDenied {
                Toggle("assessment.editor.reminder", systemImage: "bell.fill", isOn: .constant(false))
                    .disabled(true)
            } else {
                Toggle("assessment.editor.reminder", systemImage: "bell.fill", isOn: $reminderEnabled)
            }
        } footer: {
            if isDenied {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("assessment.editor.reminder.denied")
                    Button("assessment.editor.reminder.openSettings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(Typography.caption.weight(.semibold))
                }
            } else if reminderEnabled {
                if let fireDate {
                    Text("assessment.editor.reminder.at \(fireDate.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))")
                } else {
                    Text("assessment.editor.reminder.tooLate")
                }
            }
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
            let saved: Assessment
            if let assessment {
                saved = assessment
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
                saved = try repository.add(subject: subject, kind: kind, date: date, scope: scope)
            }
            lastSubjectID = subject.id.uuidString
            ReminderPreferences().setEnabled(reminderEnabled, for: saved.id)
            dismiss()
            // Zgoda jest potrzebna dopiero przy pierwszym zapisie z włączonym przypomnieniem;
            // okno systemowe pojawia się po zamknięciu arkusza, więc nie wydłuża wpisu.
            let needsAuthorization = reminderEnabled && saved.status == .upcoming && authorization == .notDetermined
            let context = modelContext
            Task {
                if needsAuthorization {
                    await ReminderScheduler.requestAuthorization()
                }
                await ReminderScheduler.sync(context: context)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func delete() {
        guard let assessment else { return }
        do {
            try AssessmentRepository(context: modelContext).delete(assessment)
            dismiss()
            let context = modelContext
            Task { await ReminderScheduler.sync(context: context) }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview("Nowy") {
    AssessmentEditorView(target: .new())
        .modelContainer(PreviewSupport.container)
}
