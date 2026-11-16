import Foundation
import SwiftData

/// Dane do podglądów SwiftUI: kontener w pamięci z wgraną listą przedmiotów,
/// profilem i kilkoma terminami.
@MainActor
public enum PreviewData {
    /// - Parameter includeSampleData: `false` — bez profilu i terminów (np. podgląd wprowadzenia).
    public static func makeContainer(includeSampleData: Bool = true) -> ModelContainer {
        do {
            let container = try Persistence.makeInMemoryContainer()
            let context = container.mainContext
            try SubjectSeeder.insertMissingDefaults(in: context)
            try context.save()
            if includeSampleData {
                try insertSampleData(in: context)
            }
            return container
        } catch {
            fatalError("Nie można przygotować danych podglądu: \(error)")
        }
    }

    private static func insertSampleData(in context: ModelContext) throws {
        try ProfileRepository(context: context).createProfile(nickname: "Ola", avatarID: "cat")

        let subjects = try SubjectRepository(context: context).allSubjects()
        let assessments = AssessmentRepository(context: context)
        let samples: [(subject: String, kind: AssessmentKind, days: Int, scope: String)] = [
            ("Biologia", .shortQuiz, 1, "Komórka roślinna"),
            ("Matematyka", .test, 4, "Funkcja liniowa"),
            ("Podstawy hotelarstwa", .classTest, 9, ""),
            ("Historia", .test, 9, "Średniowiecze"),
        ]
        for sample in samples {
            guard let subject = subjects.first(where: { $0.name == sample.subject }) else { continue }
            try assessments.add(
                subject: subject,
                kind: sample.kind,
                date: PlannerCalendar.defaultAssessmentDate(days: sample.days),
                scope: sample.scope
            )
        }
    }
}
