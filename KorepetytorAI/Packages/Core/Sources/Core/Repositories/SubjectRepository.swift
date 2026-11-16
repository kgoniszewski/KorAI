import Foundation
import SwiftData

/// Błędy zapisu przedmiotu. Opisy dla użytkowniczki tworzy warstwa aplikacji.
public enum SubjectRepositoryError: Error, Equatable, Sendable {
    /// Nazwa jest pusta (po usunięciu spacji).
    case emptyName
    /// Nazwa jest dłuższa niż `SubjectRepository.maxNameLength` znaków.
    case nameTooLong
    /// Przedmiot o tej nazwie już istnieje. Duplikaty nazw są scalane przez
    /// `SubjectSeeder.mergeDuplicates`, więc nie wolno ich tworzyć ręcznie.
    case duplicateName
    /// Przedmiot ma sprawdziany i nie może być usunięty.
    case hasAssessments(count: Int)
}

/// Dostęp do przedmiotów: lista, dodawanie, edycja i usuwanie.
public struct SubjectRepository {
    /// Maksymalna długość nazwy przedmiotu.
    public static let maxNameLength = 40

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

    /// Przedmiot o podanym identyfikatorze.
    public func subject(withID id: UUID) throws -> Subject? {
        var descriptor = FetchDescriptor<Subject>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Dodaje przedmiot na końcu listy i zapisuje.
    ///
    /// - Throws: `SubjectRepositoryError` przy niepoprawnej lub powtórzonej nazwie.
    @discardableResult
    public func addSubject(
        name: String,
        kind: SubjectKind = .general,
        colorName: String,
        iconName: String
    ) throws -> Subject {
        let validName = try validatedName(name, excluding: nil)
        let nextSortOrder = (try allSubjects().map(\.sortOrder).max() ?? -1) + 1
        let subject = Subject(
            name: validName,
            kind: kind,
            colorName: colorName,
            iconName: iconName,
            sortOrder: nextSortOrder
        )
        context.insert(subject)
        try context.save()
        return subject
    }

    /// Zmienia nazwę, kolor i ikonę przedmiotu i zapisuje.
    ///
    /// - Throws: `SubjectRepositoryError` przy niepoprawnej lub powtórzonej nazwie.
    public func update(_ subject: Subject, name: String, colorName: String, iconName: String) throws {
        let validName = try validatedName(name, excluding: subject)
        subject.name = validName
        subject.colorName = colorName
        subject.iconName = iconName
        subject.touch()
        try context.save()
    }

    /// Liczba sprawdzianów przypisanych do przedmiotu.
    public func assessmentCount(for subject: Subject) -> Int {
        subject.assessments?.count ?? 0
    }

    /// Usuwa przedmiot i zapisuje.
    ///
    /// Przedmiot ze sprawdzianami nie jest usuwany (decyzja M1: blokada z komunikatem,
    /// przeniesienie sprawdzianów na inny przedmiot w kolejnych etapach).
    ///
    /// - Throws: `SubjectRepositoryError.hasAssessments`, gdy przedmiot ma sprawdziany.
    public func delete(_ subject: Subject) throws {
        let count = assessmentCount(for: subject)
        guard count == 0 else {
            throw SubjectRepositoryError.hasAssessments(count: count)
        }
        context.delete(subject)
        try context.save()
    }

    // MARK: - Walidacja

    /// Nazwa po usunięciu skrajnych spacji, sprawdzona pod kątem długości i powtórzeń.
    ///
    /// - Parameter excluding: edytowany przedmiot (jego obecna nazwa nie jest duplikatem).
    public func validatedName(_ name: String, excluding: Subject?) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SubjectRepositoryError.emptyName
        }
        guard trimmed.count <= Self.maxNameLength else {
            throw SubjectRepositoryError.nameTooLong
        }
        let key = SubjectCatalog.normalizedKey(trimmed)
        let clash = try allSubjects().contains { other in
            other.id != excluding?.id && SubjectCatalog.normalizedKey(other.name) == key
        }
        guard !clash else {
            throw SubjectRepositoryError.duplicateName
        }
        return trimmed
    }
}
