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
