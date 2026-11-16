import Core
import Foundation
import SwiftData
import Testing

/// Kalendarz testów: stała strefa czasowa, żeby wyniki nie zależały od symulatora.
let warsawCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
    calendar.firstWeekday = 2
    return calendar
}()

/// Data w kalendarzu testów.
func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    warsawCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

@MainActor
@Suite("Repozytorium sprawdzianów")
struct AssessmentRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let repository: AssessmentRepository
    private let biology: Subject
    private let history: Subject

    init() throws {
        container = try Persistence.makeInMemoryContainer()
        context = ModelContext(container)
        biology = Subject(name: "Biologia", kind: .general, colorName: "emerald", iconName: "leaf.fill", sortOrder: 0)
        history = Subject(name: "Historia", kind: .general, colorName: "sunflower", iconName: "building.columns.fill", sortOrder: 1)
        context.insert(biology)
        context.insert(history)
        try context.save()
        repository = AssessmentRepository(context: context, calendar: warsawCalendar)
    }

    @Test("Dodanie zapisuje sprawdzian z datą na początek dnia")
    func addStoresAssessment() throws {
        let added = try repository.add(subject: biology, kind: .shortQuiz, date: makeDate(2026, 11, 20, 14, 35), scope: "  Komórka \n")

        let reader = ModelContext(container)
        let stored = try firstRecord(of: Assessment.self, in: reader)
        #expect(stored.id == added.id)
        #expect(stored.kind == .shortQuiz)
        #expect(stored.status == .upcoming)
        #expect(stored.date == makeDate(2026, 11, 20))
        #expect(stored.scope == "Komórka")
        #expect(stored.grade == nil)
        #expect(stored.subject?.id == biology.id)
    }

    @Test("Edycja zmienia wszystkie pola i przedmiot")
    func updateChangesAllFields() throws {
        let assessment = try repository.add(subject: biology, date: makeDate(2026, 11, 20))
        let before = Date(timeIntervalSince1970: 1)
        assessment.updatedAt = before

        try repository.update(
            assessment,
            subject: history,
            kind: .classTest,
            date: makeDate(2026, 12, 1, 9),
            scope: "Średniowiecze",
            status: .upcoming,
            grade: "5"
        )

        let reader = ModelContext(container)
        let stored = try firstRecord(of: Assessment.self, in: reader)
        #expect(stored.subject?.id == history.id)
        #expect(stored.kind == .classTest)
        #expect(stored.date == makeDate(2026, 12, 1))
        #expect(stored.scope == "Średniowiecze")
        #expect(stored.grade == nil, "ocena tylko dla zakończonych")
        #expect(stored.updatedAt > before)
        let biologyCount = try #require(try SubjectRepository(context: reader).subject(withID: biology.id)).assessments?.count
        #expect(biologyCount == 0)
    }

    @Test("Edycja zakończonego zapisuje ocenę")
    func updateCompletedKeepsGrade() throws {
        let assessment = try repository.add(subject: biology, date: makeDate(2026, 11, 20))
        try repository.update(
            assessment, subject: biology, kind: .test, date: assessment.date,
            scope: "", status: .completed, grade: " 4+ "
        )
        #expect(assessment.grade == "4+")
        #expect(assessment.status == .completed)
    }

    @Test("Usunięcie usuwa sprawdzian, ale nie przedmiot")
    func deleteRemovesAssessment() throws {
        let assessment = try repository.add(subject: biology, date: makeDate(2026, 11, 20))
        try repository.delete(assessment)

        let reader = ModelContext(container)
        try expectCount(of: Assessment.self, in: reader, equals: 0)
        try expectCount(of: Subject.self, in: reader, equals: 2)
    }

    @Test("Zakończenie z oceną i bez oceny")
    func markCompletedWithGrade() throws {
        let graded = try repository.add(subject: biology, date: makeDate(2026, 11, 20))
        let ungraded = try repository.add(subject: history, date: makeDate(2026, 11, 21))

        try repository.markCompleted(graded, grade: "4+")
        try repository.markCompleted(ungraded, grade: "   ")

        #expect(graded.status == .completed)
        #expect(graded.grade == "4+")
        #expect(ungraded.status == .completed)
        #expect(ungraded.grade == nil)
        let upcoming = try repository.upcoming(from: makeDate(2026, 11, 1))
        #expect(upcoming.isEmpty)
    }

    @Test("Zakres dat: początek włącznie, koniec bez, posortowane po dacie")
    func dateRange() throws {
        let late = try repository.add(subject: biology, date: makeDate(2026, 11, 30))
        let early = try repository.add(subject: history, date: makeDate(2026, 11, 1))
        _ = try repository.add(subject: biology, date: makeDate(2026, 12, 1))
        _ = try repository.add(subject: biology, date: makeDate(2026, 10, 31))

        let november = try repository.assessments(from: makeDate(2026, 11, 1), to: makeDate(2026, 12, 1))
        #expect(november.map(\.id) == [early.id, late.id])

        let all = try repository.assessments()
        #expect(all.count == 4)
        #expect(all.map(\.date) == all.map(\.date).sorted())
    }

    @Test("Filtr po przedmiocie")
    func subjectFilter() throws {
        let bio1 = try repository.add(subject: biology, date: makeDate(2026, 11, 10))
        _ = try repository.add(subject: history, date: makeDate(2026, 11, 11))
        let bio2 = try repository.add(subject: biology, date: makeDate(2026, 11, 12))

        let result = try repository.assessments(subject: biology)
        #expect(result.map(\.id) == [bio1.id, bio2.id])
    }

    @Test("Nadchodzące: tylko status upcoming od dziś, posortowane, z limitem")
    func upcomingSortedAndLimited() throws {
        let today = makeDate(2026, 11, 16, 10)
        _ = try repository.add(subject: biology, date: makeDate(2026, 11, 15))  // wczoraj
        let third = try repository.add(subject: biology, date: makeDate(2026, 11, 25))
        let first = try repository.add(subject: history, date: makeDate(2026, 11, 16))  // dziś
        let second = try repository.add(subject: biology, date: makeDate(2026, 11, 18))
        let cancelled = try repository.add(subject: biology, date: makeDate(2026, 11, 17))
        try repository.update(
            cancelled, subject: biology, kind: .test, date: cancelled.date,
            scope: "", status: .cancelled, grade: nil
        )
        let fourth = try repository.add(subject: history, date: makeDate(2026, 12, 2))

        let all = try repository.upcoming(from: today)
        #expect(all.map(\.id) == [first.id, second.id, third.id, fourth.id])

        let limited = try repository.upcoming(limit: 3, from: today)
        #expect(limited.map(\.id) == [first.id, second.id, third.id])

        let everything = try repository.allUpcoming()
        #expect(everything.count == 5, "z wczorajszym, bez odwołanego")
    }
}
