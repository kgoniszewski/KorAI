import Foundation

/// Wylicza termin przypomnienia o sprawdzianie. Czysta logika bez wywołań systemowych:
/// planowanie powiadomień (`UNUserNotificationCenter`) jest w warstwie aplikacji.
public enum ReminderPlanner {
    /// Godzina przypomnienia dnia poprzedzającego sprawdzian (decyzja M1: stała 18:00).
    public static let defaultHour = 18

    /// Przedrostek identyfikatora żądania powiadomienia.
    public static let identifierPrefix = "assessment."

    /// Identyfikator żądania powiadomienia: `assessment.<UUID>`.
    public static func identifier(for assessmentID: UUID) -> String {
        identifierPrefix + assessmentID.uuidString
    }

    /// Identyfikator sprawdzianu odczytany z identyfikatora powiadomienia;
    /// `nil` dla powiadomień, które nie dotyczą sprawdzianów.
    public static func assessmentID(fromIdentifier identifier: String) -> UUID? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(identifierPrefix.count)))
    }

    /// Termin przypomnienia: dzień przed `assessmentDate` o `hour`:00 w podanym kalendarzu.
    ///
    /// - Returns: `nil`, gdy sprawdzian nie jest nadchodzący albo termin przypomnienia
    ///   już minął (lub wypada dokładnie teraz).
    public static func reminderDate(
        assessmentDate: Date,
        status: AssessmentStatus,
        now: Date = .now,
        calendar: Calendar = .current,
        hour: Int = defaultHour
    ) -> Date? {
        guard status == .upcoming else { return nil }
        let assessmentDay = calendar.startOfDay(for: assessmentDate)
        guard
            let dayBefore = calendar.date(byAdding: .day, value: -1, to: assessmentDay),
            let fireDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayBefore)
        else {
            return nil
        }
        return fireDate > now ? fireDate : nil
    }

    /// Termin przypomnienia dla sprawdzianu.
    public static func reminderDate(
        for assessment: Assessment,
        now: Date = .now,
        calendar: Calendar = .current,
        hour: Int = defaultHour
    ) -> Date? {
        reminderDate(
            assessmentDate: assessment.date,
            status: assessment.status,
            now: now,
            calendar: calendar,
            hour: hour
        )
    }

    // MARK: - Plan dla wszystkich sprawdzianów

    /// iOS przechowuje najwyżej 64 oczekujące powiadomienia na aplikację; zostawiamy zapas.
    public static let maxScheduledReminders = 50

    /// Przypomnienia do zaplanowania: tylko włączone, nadchodzące i z terminem w przyszłości,
    /// od najbliższego, najwyżej `limit`.
    public static func plan(
        for candidates: [ReminderCandidate],
        now: Date = .now,
        calendar: Calendar = .current,
        hour: Int = defaultHour,
        limit: Int = maxScheduledReminders
    ) -> [PlannedReminder] {
        let planned = candidates.compactMap { candidate -> PlannedReminder? in
            guard
                candidate.isEnabled,
                let fireDate = reminderDate(
                    assessmentDate: candidate.assessmentDate,
                    status: candidate.status,
                    now: now,
                    calendar: calendar,
                    hour: hour
                )
            else {
                return nil
            }
            return PlannedReminder(
                identifier: identifier(for: candidate.assessmentID),
                assessmentID: candidate.assessmentID,
                fireDate: fireDate,
                kind: candidate.kind,
                subjectName: candidate.subjectName
            )
        }
        return Array(
            planned
                .sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
                .prefix(max(limit, 0))
        )
    }
}

/// Dane sprawdzianu potrzebne do zaplanowania przypomnienia (wartość, bez modelu SwiftData,
/// więc można ją przekazać do kodu powiadomień poza głównym wątkiem).
public struct ReminderCandidate: Equatable, Sendable {
    public let assessmentID: UUID
    public let assessmentDate: Date
    public let status: AssessmentStatus
    public let kind: AssessmentKind
    /// Nazwa przedmiotu; `nil`, gdy sprawdzian nie ma przedmiotu.
    public let subjectName: String?
    /// Przełącznik przypomnienia w edytorze (`ReminderPreferences`).
    public let isEnabled: Bool

    public init(
        assessmentID: UUID,
        assessmentDate: Date,
        status: AssessmentStatus,
        kind: AssessmentKind,
        subjectName: String?,
        isEnabled: Bool
    ) {
        self.assessmentID = assessmentID
        self.assessmentDate = assessmentDate
        self.status = status
        self.kind = kind
        self.subjectName = subjectName
        self.isEnabled = isEnabled
    }

    public init(_ assessment: Assessment, isEnabled: Bool) {
        self.init(
            assessmentID: assessment.id,
            assessmentDate: assessment.date,
            status: assessment.status,
            kind: assessment.kind,
            subjectName: assessment.subject?.name,
            isEnabled: isEnabled
        )
    }
}

/// Przypomnienie gotowe do zaplanowania w `UNUserNotificationCenter`.
public struct PlannedReminder: Equatable, Sendable {
    /// Identyfikator żądania: `assessment.<UUID>`.
    public let identifier: String
    public let assessmentID: UUID
    public let fireDate: Date
    public let kind: AssessmentKind
    public let subjectName: String?

    public init(identifier: String, assessmentID: UUID, fireDate: Date, kind: AssessmentKind, subjectName: String?) {
        self.identifier = identifier
        self.assessmentID = assessmentID
        self.fireDate = fireDate
        self.kind = kind
        self.subjectName = subjectName
    }
}
