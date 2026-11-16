import Core
import Foundation
import Testing

@Suite("Planowanie przypomnień")
struct ReminderPlannerTests {
    private func reminder(for date: Date, status: AssessmentStatus = .upcoming, now: Date) -> Date? {
        ReminderPlanner.reminderDate(assessmentDate: date, status: status, now: now, calendar: warsawCalendar)
    }

    @Test("Dzień wcześniej o 18:00")
    func dayBeforeAtSixPM() {
        let result = reminder(for: makeDate(2026, 11, 20), now: makeDate(2026, 11, 16, 12))
        #expect(result == makeDate(2026, 11, 19, 18))
    }

    @Test("Godzina sprawdzianu nie zmienia terminu przypomnienia")
    func ignoresTimeOfDay() {
        let result = reminder(for: makeDate(2026, 11, 20, 8, 15), now: makeDate(2026, 11, 16, 12))
        #expect(result == makeDate(2026, 11, 19, 18))
    }

    @Test("Brak przypomnienia dla sprawdzianu w przeszłości")
    func nilForPastAssessment() {
        #expect(reminder(for: makeDate(2026, 11, 10), now: makeDate(2026, 11, 16, 12)) == nil)
    }

    @Test("Brak przypomnienia, gdy 18:00 dnia poprzedniego już minęła")
    func nilWhenReminderTimePassed() {
        // Sprawdzian jutro, a jest 19:00.
        #expect(reminder(for: makeDate(2026, 11, 17), now: makeDate(2026, 11, 16, 19)) == nil)
        // Sprawdzian dziś.
        #expect(reminder(for: makeDate(2026, 11, 16), now: makeDate(2026, 11, 16, 7)) == nil)
        // Dokładnie 18:00 to już za późno.
        #expect(reminder(for: makeDate(2026, 11, 17), now: makeDate(2026, 11, 16, 18)) == nil)
        // Minutę wcześniej jeszcze zdąży.
        #expect(reminder(for: makeDate(2026, 11, 17), now: makeDate(2026, 11, 16, 17, 59)) == makeDate(2026, 11, 16, 18))
    }

    @Test("Brak przypomnienia dla zakończonego lub odwołanego", arguments: [AssessmentStatus.completed, .cancelled])
    func nilForNonUpcoming(status: AssessmentStatus) {
        #expect(reminder(for: makeDate(2026, 11, 20), status: status, now: makeDate(2026, 11, 16)) == nil)
    }

    @Test("Granica miesiąca")
    func crossesMonthBoundary() {
        #expect(reminder(for: makeDate(2026, 12, 1), now: makeDate(2026, 11, 16)) == makeDate(2026, 11, 30, 18))
        // Luty w roku nieprzestępnym.
        #expect(reminder(for: makeDate(2027, 3, 1), now: makeDate(2027, 2, 1)) == makeDate(2027, 2, 28, 18))
    }

    @Test("Granica roku")
    func crossesYearBoundary() {
        #expect(reminder(for: makeDate(2027, 1, 1), now: makeDate(2026, 12, 20)) == makeDate(2026, 12, 31, 18))
    }

    @Test("Zmiana czasu: 18:00 czasu lokalnego także dzień po przejściu na czas letni")
    func daylightSavingTime() {
        // W 2027 r. czas letni w Polsce zaczyna się 28 marca.
        #expect(reminder(for: makeDate(2027, 3, 29), now: makeDate(2027, 3, 1)) == makeDate(2027, 3, 28, 18))
    }

    @Test("Identyfikator powiadomienia: assessment.<UUID> i odczyt z powrotem")
    func identifierRoundTrip() throws {
        let id = UUID()
        let identifier = ReminderPlanner.identifier(for: id)
        #expect(identifier == "assessment.\(id.uuidString)")
        #expect(ReminderPlanner.assessmentID(fromIdentifier: identifier) == id)
        #expect(ReminderPlanner.assessmentID(fromIdentifier: "other.\(id.uuidString)") == nil)
        #expect(ReminderPlanner.assessmentID(fromIdentifier: "assessment.nie-uuid") == nil)
    }

    private func candidate(
        _ date: Date,
        status: AssessmentStatus = .upcoming,
        enabled: Bool = true,
        id: UUID = UUID()
    ) -> ReminderCandidate {
        ReminderCandidate(
            assessmentID: id,
            assessmentDate: date,
            status: status,
            kind: .test,
            subjectName: "Biologia",
            isEnabled: enabled
        )
    }

    @Test("Plan: tylko włączone i przyszłe, od najbliższego")
    func planFiltersAndSorts() {
        let now = makeDate(2026, 11, 16, 12)
        let late = candidate(makeDate(2026, 11, 30))
        let soon = candidate(makeDate(2026, 11, 18))
        let candidates = [
            late,
            candidate(makeDate(2026, 11, 20), enabled: false),
            candidate(makeDate(2026, 11, 10)),
            candidate(makeDate(2026, 11, 21), status: .completed),
            soon,
        ]

        let plan = ReminderPlanner.plan(for: candidates, now: now, calendar: warsawCalendar)

        let actual: [UUID] = plan.map(\.assessmentID)
        let expected: [UUID] = [soon.assessmentID, late.assessmentID]
        #expect(actual == expected)
        #expect(plan.first?.fireDate == makeDate(2026, 11, 17, 18))
        #expect(plan.first?.identifier == ReminderPlanner.identifier(for: soon.assessmentID))
        #expect(plan.first?.subjectName == "Biologia")
    }

    @Test("Plan: najwyżej limit przypomnień, najbliższe mają pierwszeństwo")
    func planRespectsLimit() {
        let now = makeDate(2026, 11, 16, 12)
        let candidates = (1...70).map { candidate(makeDate(2026, 11, 16).addingTimeInterval(Double($0) * 86_400)) }

        let plan = ReminderPlanner.plan(for: candidates.shuffled(), now: now, calendar: warsawCalendar)

        #expect(plan.count == ReminderPlanner.maxScheduledReminders)
        #expect(plan.map(\.assessmentID) == candidates.prefix(ReminderPlanner.maxScheduledReminders).map(\.assessmentID))
    }
}

@MainActor
@Suite("Ustawienia przypomnień")
struct ReminderPreferencesTests {
    private let preferences: ReminderPreferences

    init() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReminderPreferencesTests.\(UUID().uuidString)"))
        preferences = ReminderPreferences(defaults: defaults)
    }

    @Test("Domyślnie włączone; wyłączenie i ponowne włączenie")
    func toggle() {
        let id = UUID()
        #expect(preferences.isEnabled(for: id))

        preferences.setEnabled(false, for: id)
        #expect(!preferences.isEnabled(for: id))
        #expect(preferences.isEnabled(for: UUID()))

        preferences.setEnabled(true, for: id)
        #expect(preferences.isEnabled(for: id))
        #expect(preferences.disabledIDs.isEmpty)
    }

    @Test("Usuwa wpisy nieistniejących sprawdzianów")
    func removesOrphans() {
        let kept = UUID()
        let removed = UUID()
        preferences.setEnabled(false, for: kept)
        preferences.setEnabled(false, for: removed)

        preferences.removeEntries(notIn: [kept, UUID()])

        let actual: Set<UUID> = preferences.disabledIDs
        let expected: Set<UUID> = [kept]
        #expect(actual == expected)
    }
}
