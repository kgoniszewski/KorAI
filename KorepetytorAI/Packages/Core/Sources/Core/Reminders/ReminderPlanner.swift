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
}
