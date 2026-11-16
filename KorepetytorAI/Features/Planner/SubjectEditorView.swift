import Core
import DesignSystem
import SwiftData
import SwiftUI

/// Dodawanie i edycja przedmiotu: nazwa, kolor z palety i ikona z krótkiej listy.
struct SubjectEditorView: View {
    /// Edytowany przedmiot; `nil` — nowy przedmiot (rodzaj ogólny, na końcu listy).
    let subject: Subject?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var colorName: String
    @State private var iconName: String
    @State private var errorMessage: LocalizedStringKey?

    @ScaledMetric(relativeTo: .title2) private var swatchSize: CGFloat = 40

    init(subject: Subject?, suggestedColorName: String = SubjectPalette.slate.rawValue) {
        self.subject = subject
        _name = State(initialValue: subject?.name ?? "")
        _colorName = State(initialValue: subject?.colorName ?? suggestedColorName)
        _iconName = State(initialValue: subject?.iconName ?? SubjectIcons.defaultIcon)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName.count <= SubjectRepository.maxNameLength
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: swatchSize + Spacing.s), spacing: Spacing.m)]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("subjects.editor.namePlaceholder", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onChange(of: name) { _, newValue in
                            errorMessage = nil
                            if newValue.count > SubjectRepository.maxNameLength {
                                name = String(newValue.prefix(SubjectRepository.maxNameLength))
                            }
                        }
                } header: {
                    Text("subjects.editor.name")
                } footer: {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(SubjectPalette.rose.color)
                    } else {
                        Text("subjects.editor.nameCounter \(name.count) \(SubjectRepository.maxNameLength)")
                    }
                }

                Section("subjects.editor.color") {
                    LazyVGrid(columns: columns, spacing: Spacing.m) {
                        ForEach(SubjectPalette.allCases, id: \.self) { color in
                            colorSwatch(color)
                        }
                    }
                    .padding(.vertical, Spacing.s)
                }

                Section("subjects.editor.icon") {
                    LazyVGrid(columns: columns, spacing: Spacing.m) {
                        ForEach(SubjectIcons.all, id: \.self) { icon in
                            iconButton(icon)
                        }
                    }
                    .padding(.vertical, Spacing.s)
                }

                Section("subjects.editor.preview") {
                    SubjectChip(
                        name: trimmedName.isEmpty ? String(localized: "subjects.editor.namePlaceholder") : trimmedName,
                        colorName: colorName,
                        iconName: iconName
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(subject == nil ? LocalizedStringKey("subjects.editor.newTitle") : LocalizedStringKey("subjects.editor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func colorSwatch(_ color: SubjectPalette) -> some View {
        let isSelected = color.rawValue == colorName
        return Button {
            colorName = color.rawValue
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: swatchSize, height: swatchSize)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(Typography.headline)
                            .foregroundStyle(Palette.accentForeground)
                    }
                }
                .padding(Spacing.xs)
                .overlay(Circle().strokeBorder(isSelected ? color.color : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("subjects.editor.colorOption \(color.rawValue)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func iconButton(_ icon: String) -> some View {
        let isSelected = icon == iconName
        let tint = SubjectPalette.color(named: colorName)
        return Button {
            iconName = icon
        } label: {
            Image(systemName: icon)
                .font(Typography.headline)
                .foregroundStyle(isSelected ? Palette.accentForeground : tint)
                .frame(width: swatchSize, height: swatchSize)
                .background(
                    isSelected ? tint : tint.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save() {
        let repository = SubjectRepository(context: modelContext)
        do {
            if let subject {
                try repository.update(subject, name: name, colorName: colorName, iconName: iconName)
            } else {
                try repository.addSubject(name: name, kind: .general, colorName: colorName, iconName: iconName)
            }
            dismiss()
        } catch let error as SubjectRepositoryError {
            errorMessage = error.message
        } catch {
            errorMessage = "subjects.error.saveFailed"
        }
    }
}

extension SubjectRepositoryError {
    /// Komunikat dla użytkowniczki.
    var message: LocalizedStringKey {
        switch self {
        case .emptyName: "subjects.error.emptyName"
        case .nameTooLong: "subjects.error.nameTooLong \(SubjectRepository.maxNameLength)"
        case .duplicateName: "subjects.error.duplicateName"
        case .hasAssessments(let count): "subjects.delete.blocked.message \(count)"
        }
    }
}

#Preview("Nowy") {
    SubjectEditorView(subject: nil)
        .modelContainer(PreviewSupport.container)
}
