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

    /// Wgrywa brakujące przedmioty (raz na instalację i magazyn) i scala duplikaty, po czym zapisuje.
    ///
    /// Wgrywanie raz na instalację sprawia, że przedmiot usunięty przez użytkowniczkę
    /// nie wraca przy kolejnym starcie. Flaga jest osobna dla każdego magazynu
    /// (iCloud, lokalny), żeby uruchomienie w innym trybie nie zostawiło pustej bazy,
    /// i jest zapisywana dopiero po udanym zapisie.
    ///
    /// - Parameter storeKey: identyfikator magazynu, np. `cloud` lub `local`;
    ///   `nil` (baza w pamięci) wgrywa brakujące przedmioty bez flagi.
    @discardableResult
    public static func run(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        storeKey: String? = "cloud"
    ) throws -> Report {
        let flagKey = storeKey.map { "\(seededVersionKey).\($0)" }
        let needsSeed = flagKey.map { defaults.integer(forKey: $0) < seedVersion } ?? true

        var report = Report()
        if needsSeed {
            report.inserted = try insertMissingDefaults(in: context)
        }
        report.merged = try mergeDuplicates(in: context)
        if context.hasChanges {
            try context.save()
        }
        if needsSeed, let flagKey {
            defaults.set(seedVersion, forKey: flagKey)
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
