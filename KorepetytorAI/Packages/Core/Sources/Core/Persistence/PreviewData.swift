import Foundation
import SwiftData

/// Dane do podglądów SwiftUI: kontener w pamięci z wgraną listą przedmiotów.
@MainActor
public enum PreviewData {
    public static func makeContainer() -> ModelContainer {
        do {
            let container = try Persistence.makeInMemoryContainer()
            try SubjectSeeder.insertMissingDefaults(in: container.mainContext)
            try container.mainContext.save()
            return container
        } catch {
            fatalError("Nie można przygotować danych podglądu: \(error)")
        }
    }
}
