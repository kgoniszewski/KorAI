import Foundation
import SwiftData

/// Wgrywa listę przedmiotów i scala duplikaty.
///
/// Oba urządzenia mogą wgrać listę, zanim zdążą się zsynchronizować, więc po
/// synchronizacji w bazie byłoby 32 przedmioty. Dlatego scalanie duplikatów
/// działa przy każdym starcie, przy powrocie aplikacji na pierwszy plan
/// i po zmianach przychodzących z iCloud.
///
/// Scalanie jest deterministyczne: zostaje rekord o najwcześniejszym `createdAt`
/// (przy remisie: o najmniejszym `id`). Oba urządzenia wybierają więc ten sam
/// rekord i nigdy nie usuną sobie nawzajem obu kopii.
public enum SubjectSeeder {
    /// Wersja listy startowej. Podniesienie wersji dogra nowe przedmioty z listy.
    public static let seedVersion = 1
    /// Klucz w `UserDefaults` (lokalny dla instalacji, nie synchronizuje się).
    public static let seededVersionKey = "SubjectSeeder.seededVersion"

    public struct Report: Equatable, Sendable {
        public var inserted: Int
        public var merged: Int

        public init(inserted: Int = 0, merged: Int = 0) {
            self.inserted = inserted
            self.merged = merged
        }
    }

    /// Wgrywa brakujące przedmioty (raz na instalację) i scala duplikaty, po czym zapisuje.
    ///
    /// Wgrywanie raz na instalację sprawia, że przedmiot usunięty przez użytkowniczkę
    /// nie wraca przy kolejnym starcie.
    @discardableResult
    public static func run(in context: ModelContext, defaults: UserDefaults = .standard) throws -> Report {
        var report = Report()
        if defaults.integer(forKey: seededVersionKey) < seedVersion {
            report.inserted = try insertMissingDefaults(in: context)
            defaults.set(seedVersion, forKey: seededVersionKey)
        }
        report.merged = try mergeDuplicates(in: context)
        if context.hasChanges {
            try context.save()
        }
        return report
    }

    /// Dodaje przedmioty z listy startowej, których nazw jeszcze nie ma w bazie. Nie zapisuje.
    @discardableResult
    public static func insertMissingDefaults(in context: ModelContext) throws -> Int {
        let existing = try context.fetch(FetchDescriptor<Subject>())
        let existingKeys = Set(existing.map { SubjectCatalog.normalizedKey($0.name) })

        var inserted = 0
        for (index, seed) in SubjectCatalog.defaultSubjects.enumerated()
        where !existingKeys.contains(SubjectCatalog.normalizedKey(seed.name)) {
            let subject = Subject(
                name: seed.name,
                kind: seed.kind,
                colorName: seed.colorName,
                iconName: seed.iconName,
                sortOrder: index
            )
            context.insert(subject)
            inserted += 1
        }
        return inserted
    }

    /// Scala przedmioty o tej samej nazwie. Sprawdziany i materiały duplikatów
    /// przechodzą do zachowanego rekordu. Nie zapisuje.
    ///
    /// - Returns: liczba usuniętych duplikatów.
    @discardableResult
    public static func mergeDuplicates(in context: ModelContext) throws -> Int {
        let subjects = try context.fetch(FetchDescriptor<Subject>())
        let groups = Dictionary(grouping: subjects) { SubjectCatalog.normalizedKey($0.name) }

        var removed = 0
        for (key, group) in groups where !key.isEmpty && group.count > 1 {
            let ordered = group.sorted(by: isPreferredSurvivor)
            let survivor = ordered[0]
            var movedRelationships = false

            for duplicate in ordered.dropFirst() {
                for assessment in duplicate.assessments ?? [] {
                    assessment.subject = survivor
                    movedRelationships = true
                }
                for material in duplicate.materials ?? [] {
                    material.subject = survivor
                    movedRelationships = true
                }
                context.delete(duplicate)
                removed += 1
            }

            if movedRelationships {
                survivor.touch()
            }
        }
        return removed
    }

    /// Kolejność wyboru rekordu, który zostaje: najstarszy, przy remisie najmniejsze `id`.
    static func isPreferredSurvivor(_ lhs: Subject, _ rhs: Subject) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
