import Foundation
import SwiftData

/// Dostęp do przedmiotów. W M0 służy ekranowi Profil do testu synchronizacji;
/// pełną edycję listy dostaje M1.
public struct SubjectRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Wszystkie przedmioty w kolejności wyświetlania.
    public func allSubjects() throws -> [Subject] {
        let descriptor = FetchDescriptor<Subject>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    /// Dodaje przedmiot na końcu listy i zapisuje.
    @discardableResult
    public func addSubject(
        name: String,
        kind: SubjectKind,
        colorName: String,
        iconName: String
    ) throws -> Subject {
        let nextSortOrder = (try allSubjects().map(\.sortOrder).max() ?? -1) + 1
        let subject = Subject(
            name: name,
            kind: kind,
            colorName: colorName,
            iconName: iconName,
            sortOrder: nextSortOrder
        )
        context.insert(subject)
        try context.save()
        return subject
    }

    /// Usuwa przedmiot i zapisuje.
    public func delete(_ subject: Subject) throws {
        context.delete(subject)
        try context.save()
    }
}
