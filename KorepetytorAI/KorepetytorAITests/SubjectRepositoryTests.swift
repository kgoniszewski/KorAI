import Core
import Foundation
import SwiftData
import Testing

@MainActor
@Suite("Repozytorium przedmiotów")
struct SubjectRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let repository: SubjectRepository

    init() throws {
        container = try Persistence.makeInMemoryContainer()
        context = ModelContext(container)
        try SubjectSeeder.insertMissingDefaults(in: context)
        try context.save()
        repository = SubjectRepository(context: context)
    }

    @Test("Nowy przedmiot trafia na koniec listy jako ogólny")
    func addAppendsAtEnd() throws {
        let added = try repository.addSubject(name: "Test", colorName: "slate", iconName: "star")

        let all = try repository.allSubjects()
        #expect(all.count == 17)
        #expect(all.last?.id == added.id)
        #expect(added.sortOrder == 16)
        #expect(added.kind == .general)

        try repository.delete(added)
        let afterDelete = try repository.allSubjects()
        #expect(afterDelete.count == 16)
    }

    @Test("Edycja zmienia nazwę, kolor, ikonę i updatedAt")
    func updateChangesFields() throws {
        let subject = try repository.addSubject(name: "Chemia", colorName: "slate", iconName: "star")
        let before = Date(timeIntervalSince1970: 1)
        subject.updatedAt = before

        try repository.update(subject, name: "  Chemia organiczna ", colorName: "lime", iconName: "flask.fill")

        let reader = ModelContext(container)
        let stored = try #require(try SubjectRepository(context: reader).subject(withID: subject.id))
        #expect(stored.name == "Chemia organiczna")
        #expect(stored.colorName == "lime")
        #expect(stored.iconName == "flask.fill")
        #expect(stored.updatedAt > before)
    }

    @Test("Nazwa jest wymagana i ma najwyżej 40 znaków")
    func nameValidation() throws {
        #expect(throws: SubjectRepositoryError.emptyName) {
            try repository.addSubject(name: "   ", colorName: "slate", iconName: "star")
        }
        #expect(throws: SubjectRepositoryError.nameTooLong) {
            try repository.addSubject(name: String(repeating: "a", count: 41), colorName: "slate", iconName: "star")
        }
        let longest = try repository.addSubject(name: String(repeating: "a", count: 40), colorName: "slate", iconName: "star")
        #expect(longest.name.count == 40)
    }

    @Test("Nie można utworzyć ani nazwać przedmiotu tak jak istniejący")
    func duplicateNamesAreRejected() throws {
        #expect(throws: SubjectRepositoryError.duplicateName) {
            try repository.addSubject(name: "matematyka ", colorName: "slate", iconName: "star")
        }

        let physics = try #require(try repository.allSubjects().first { $0.name == "Fizyka" })
        #expect(throws: SubjectRepositoryError.duplicateName) {
            try repository.update(physics, name: "Język Polski", colorName: physics.colorName, iconName: physics.iconName)
        }
        // Własna nazwa (np. zmiana tylko koloru) nie jest duplikatem.
        try repository.update(physics, name: "Fizyka", colorName: "rose", iconName: physics.iconName)
        #expect(physics.colorName == "rose")
    }

    @Test("Przedmiot ze sprawdzianami nie może być usunięty")
    func deleteIsRefusedWhenSubjectHasAssessments() throws {
        let subject = try #require(try repository.allSubjects().first { $0.name == "Biologia" })
        let assessments = AssessmentRepository(context: context)
        try assessments.add(subject: subject, date: .now)
        try assessments.add(subject: subject, kind: .shortQuiz, date: .now)

        #expect(throws: SubjectRepositoryError.hasAssessments(count: 2)) {
            try repository.delete(subject)
        }
        try expectCount(of: Subject.self, in: ModelContext(container), equals: 16)
        try expectCount(of: Assessment.self, in: ModelContext(container), equals: 2)
    }
}
