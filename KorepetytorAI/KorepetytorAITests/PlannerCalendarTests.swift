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

    @Test("Siatka listopada 2026: zaczyna się w niedzielę, więc 6 pustych pól")
    func novemberGrid() {
        let grid = PlannerCalendar.monthGrid(for: makeDate(2026, 11, 16, 12), calendar: warsawCalendar)
        #expect(grid.month == makeDate(2026, 11, 1))
        #expect(grid.leadingBlanks == 6)
        #expect(grid.days.count == 30)
        #expect(grid.days.first == makeDate(2026, 11, 1))
        #expect(grid.days.last == makeDate(2026, 11, 30))
        #expect(grid.weekCount == 6)
    }

    @Test("Siatka lutego 2027: zaczyna się w poniedziałek, 4 tygodnie")
    func februaryGrid() {
        let grid = PlannerCalendar.monthGrid(for: makeDate(2027, 2, 10), calendar: warsawCalendar)
        #expect(grid.leadingBlanks == 0)
        #expect(grid.days.count == 28)
        #expect(grid.weekCount == 4)
    }

    @Test("Tydzień od poniedziałku także przy kalendarzu z niedzielą jako pierwszym dniem")
    func gridIgnoresLocaleFirstWeekday() {
        var sundayFirst = warsawCalendar
        sundayFirst.firstWeekday = 1
        let grid = PlannerCalendar.monthGrid(for: makeDate(2026, 11, 1), calendar: sundayFirst)
        #expect(grid.leadingBlanks == 6)
    }

    @Test("Przesuwanie miesięcy przez granicę roku")
    func monthNavigation() {
        #expect(PlannerCalendar.month(byAdding: 1, to: makeDate(2026, 12, 31, 20), calendar: warsawCalendar) == makeDate(2027, 1, 1))
        #expect(PlannerCalendar.month(byAdding: -1, to: makeDate(2027, 1, 15), calendar: warsawCalendar) == makeDate(2026, 12, 1))
        #expect(PlannerCalendar.month(byAdding: 1, to: makeDate(2027, 1, 31), calendar: warsawCalendar) == makeDate(2027, 2, 1))
    }

    @Test("Nazwy dni tygodnia od poniedziałku")
    func weekdaySymbols() {
        var calendar = warsawCalendar
        calendar.locale = Locale(identifier: "pl_PL")
        let symbols = PlannerCalendar.weekdaySymbolsMondayFirst(calendar: calendar)
        #expect(symbols.count == 7)
        #expect(symbols.first == calendar.shortStandaloneWeekdaySymbols[1])
        #expect(symbols.last == calendar.shortStandaloneWeekdaySymbols[0])
    }
}
