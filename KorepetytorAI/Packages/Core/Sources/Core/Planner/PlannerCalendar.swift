import Foundation

/// Obliczenia kalendarzowe Planera i ekranu Dziś. Czysta logika, testowalna bez UI.
public enum PlannerCalendar {
    /// Liczba dni kalendarzowych od `from` do `to` (ujemna dla dat w przeszłości).
    /// Liczy dni, nie pełne doby: z wieczora do rana następnego dnia to 1.
    public static func daysBetween(_ from: Date, and to: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Domyślna data nowego sprawdzianu: początek dnia za `days` dni.
    public static func defaultAssessmentDate(now: Date = .now, days: Int = 7, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: days, to: today) ?? today
    }

    /// Grupuje elementy według dnia (początek dnia w kalendarzu), w kolejności rosnącej dat.
    /// Kolejność elementów w grupie jest zachowana.
    public static func groupedByDay<Element>(
        _ elements: [Element],
        calendar: Calendar = .current,
        date: (Element) -> Date
    ) -> [DayGroup<Element>] {
        let groups = Dictionary(grouping: elements) { calendar.startOfDay(for: date($0)) }
        return groups.keys.sorted().map { day in DayGroup(day: day, items: groups[day] ?? []) }
    }

    // MARK: - Miesiąc

    /// Kalendarz z tygodniem od poniedziałku (niezależnie od ustawień regionu),
    /// z tą samą strefą czasową i ustawieniami regionalnymi co `calendar`.
    public static func mondayFirst(_ calendar: Calendar = .current) -> Calendar {
        var result = calendar
        result.firstWeekday = 2
        return result
    }

    /// Początek miesiąca zawierającego `date`.
    public static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Początek miesiąca przesuniętego o `months` względem miesiąca zawierającego `date`.
    public static func month(byAdding months: Int, to date: Date, calendar: Calendar = .current) -> Date {
        let start = startOfMonth(for: date, calendar: calendar)
        return calendar.date(byAdding: .month, value: months, to: start) ?? start
    }

    /// Siatka miesiąca z tygodniem od poniedziałku.
    public static func monthGrid(for date: Date, calendar: Calendar = .current) -> MonthGrid {
        let calendar = mondayFirst(calendar)
        let start = startOfMonth(for: date, calendar: calendar)
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 0
        let weekday = calendar.component(.weekday, from: start)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        let days = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return MonthGrid(month: start, leadingBlanks: leadingBlanks, days: days)
    }

    /// Krótkie nazwy dni tygodnia od poniedziałku (np. „pon.”, „wt.”).
    public static func weekdaySymbolsMondayFirst(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        return Array(symbols[1...] + symbols[..<1])
    }
}

/// Elementy jednego dnia.
public struct DayGroup<Element>: Identifiable {
    /// Początek dnia.
    public let day: Date
    public let items: [Element]

    public var id: Date { day }

    public init(day: Date, items: [Element]) {
        self.day = day
        self.items = items
    }
}

/// Dni jednego miesiąca ułożone w tygodnie od poniedziałku.
public struct MonthGrid: Equatable, Sendable {
    /// Początek miesiąca.
    public let month: Date
    /// Liczba pustych pól przed pierwszym dniem (0 — miesiąc zaczyna się w poniedziałek).
    public let leadingBlanks: Int
    /// Początki kolejnych dni miesiąca.
    public let days: [Date]

    public init(month: Date, leadingBlanks: Int, days: [Date]) {
        self.month = month
        self.leadingBlanks = leadingBlanks
        self.days = days
    }

    /// Liczba tygodni (wierszy) w siatce.
    public var weekCount: Int {
        (leadingBlanks + days.count + 6) / 7
    }
}
