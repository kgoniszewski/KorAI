import Foundation
import SwiftData

/// Dostęp do kartkówek, sprawdzianów i prac klasowych.
///
/// Data sprawdzianu jest zapisywana jako początek dnia w kalendarzu urządzenia:
/// formularz wybiera tylko dzień, a jedna wartość na dzień upraszcza grupowanie
/// w Planerze i wyliczanie przypomnień.
public struct AssessmentRepository {
    private let context: ModelContext
    private let calendar: Calendar

    public init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: - Odczyt

    /// Sprawdziany z przedziału `[from, to)`, posortowane po dacie
    /// (przy tej samej dacie: po dacie utworzenia).
    ///
    /// - Parameters:
    ///   - from: początek przedziału (włącznie); `nil` — bez ograniczenia.
    ///   - to: koniec przedziału (bez tej chwili); `nil` — bez ograniczenia.
    ///   - subject: tylko sprawdziany tego przedmiotu; `nil` — wszystkie.
    public func assessments(from: Date? = nil, to: Date? = nil, subject: Subject? = nil) throws -> [Assessment] {
        let start = from ?? .distantPast
        let end = to ?? .distantFuture
        let descriptor = FetchDescriptor<Assessment>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt)]
        )
        let result = try context.fetch(descriptor)
        // Filtr po przedmiocie w pamięci: porównanie relacji w `#Predicate`
        // bywa zawodne, a sprawdzianów jest najwyżej kilkaset.
        guard let subjectID = subject?.id else { return result }
        return result.filter { $0.subject?.id == subjectID }
    }

    /// Nadchodzące sprawdziany (status `upcoming`) od początku dnia `from`, posortowane po dacie.
    /// Sprawdzian zaplanowany na dziś jest jeszcze nadchodzący.
    ///
    /// - Parameter limit: maksymalna liczba wyników; `nil` — wszystkie.
    public func upcoming(limit: Int? = nil, from: Date = .now) throws -> [Assessment] {
        let start = calendar.startOfDay(for: from)
        let upcomingRaw = AssessmentStatus.upcoming.rawValue
        var descriptor = FetchDescriptor<Assessment>(
            predicate: #Predicate { $0.statusRaw == upcomingRaw && $0.date >= start },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt)]
        )
        if let limit {
            descriptor.fetchLimit = max(limit, 0)
        }
        return try context.fetch(descriptor)
    }

    /// Wszystkie nadchodzące sprawdziany, także te z datą w przeszłości
    /// (np. do przeplanowania przypomnień).
    public func allUpcoming() throws -> [Assessment] {
        let upcomingRaw = AssessmentStatus.upcoming.rawValue
        let descriptor = FetchDescriptor<Assessment>(
            predicate: #Predicate { $0.statusRaw == upcomingRaw },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Zapis

    /// Dodaje nadchodzący sprawdzian i zapisuje.
    @discardableResult
    public func add(
        subject: Subject,
        kind: AssessmentKind = .test,
        date: Date,
        scope: String = ""
    ) throws -> Assessment {
        let assessment = Assessment(
            kind: kind,
            date: calendar.startOfDay(for: date),
            scope: Self.normalizedScope(scope),
            status: .upcoming
        )
        context.insert(assessment)
        assessment.subject = subject
        subject.touch()
        try context.save()
        return assessment
    }

    /// Zmienia wszystkie pola sprawdzianu i zapisuje.
    ///
    /// Ocena jest zapisywana tylko dla statusu `completed`; przy innym statusie pole jest czyszczone.
    public func update(
        _ assessment: Assessment,
        subject: Subject,
        kind: AssessmentKind,
        date: Date,
        scope: String,
        status: AssessmentStatus,
        grade: String?
    ) throws {
        if assessment.subject?.id != subject.id {
            assessment.subject?.touch()
            assessment.subject = subject
            subject.touch()
        }
        assessment.kind = kind
        assessment.date = calendar.startOfDay(for: date)
        assessment.scope = Self.normalizedScope(scope)
        assessment.status = status
        assessment.grade = status == .completed ? Self.normalizedGrade(grade) : nil
        assessment.touch()
        try context.save()
    }

    /// Oznacza sprawdzian jako zakończony, opcjonalnie z oceną, i zapisuje.
    public func markCompleted(_ assessment: Assessment, grade: String? = nil) throws {
        assessment.status = .completed
        assessment.grade = Self.normalizedGrade(grade)
        assessment.touch()
        try context.save()
    }

    /// Usuwa sprawdzian i zapisuje. Sesje planu nauki znikają razem z nim (reguła `cascade`).
    public func delete(_ assessment: Assessment) throws {
        context.delete(assessment)
        try context.save()
    }

    // MARK: - Pomocnicze

    /// Ocena bez skrajnych spacji; pusta oznacza brak oceny.
    public static func normalizedGrade(_ grade: String?) -> String? {
        guard let trimmed = grade?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// Zakres bez skrajnych pustych linii i spacji.
    public static func normalizedScope(_ scope: String) -> String {
        scope.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
