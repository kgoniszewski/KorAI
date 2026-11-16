import Core
import Foundation
import Testing

@Suite("Kalendarz Planera")
struct PlannerCalendarTests {
    @Test("Odliczanie liczy dni kalendarzowe")
    func daysBetweenCountsCalendarDays() {
        let evening = makeDate(2026, 11, 16, 22)
        #expect(PlannerCalendar.daysBetween(evening, and: makeDate(2026, 11, 17, 8), calendar: warsawCalendar) == 1)
        #expect(PlannerCalendar.daysBetween(evening, and: makeDate(2026, 11, 16), calendar: warsawCalendar) == 0)
        #expect(PlannerCalendar.daysBetween(evening, and: makeDate(2026, 11, 23), calendar: warsawCalendar) == 7)
        #expect(PlannerCalendar.daysBetween(evening, and: makeDate(2026, 11, 14), calendar: warsawCalendar) == -2)
        #expect(PlannerCalendar.daysBetween(makeDate(2026, 12, 30), and: makeDate(2027, 1, 2), calendar: warsawCalendar) == 3)
    }

    @Test("Domyślna data sprawdzianu: za 7 dni, początek dnia")
    func defaultDateIsInSevenDays() {
        let result = PlannerCalendar.defaultAssessmentDate(now: makeDate(2026, 11, 28, 15), calendar: warsawCalendar)
        #expect(result == makeDate(2026, 12, 5))
    }

    @Test("Grupowanie po dniu, rosnąco")
    func groupsByDay() {
        let dates = [makeDate(2026, 11, 20, 9), makeDate(2026, 11, 18), makeDate(2026, 11, 20, 15)]
        let groups = PlannerCalendar.groupedByDay(dates, calendar: warsawCalendar) { $0 }
        #expect(groups.map(\.day) == [makeDate(2026, 11, 18), makeDate(2026, 11, 20)])
        #expect(groups.map(\.items.count) == [1, 2])
    }
}
