import Core
import DesignSystem
import Foundation
import SwiftData
import Testing
import UIKit

@MainActor
@Suite("Przedmioty startowe")
struct SubjectSeederTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let defaults: UserDefaults

    init() throws {
        container = try Persistence.makeInMemoryContainer()
        context = ModelContext(container)
        defaults = try #require(UserDefaults(suiteName: "SubjectSeederTests.\(UUID().uuidString)"))
    }

    private func subjects(in context: ModelContext? = nil) throws -> [Subject] {
        try (context ?? self.context).fetch(FetchDescriptor<Subject>())
    }

    @Test("Pierwsze uruchomienie wgrywa 16 przedmiotów: 10 ogólnych i 6 zawodowych")
    func firstRunSeedsSixteenSubjects() throws {
        let report = try SubjectSeeder.run(in: context, defaults: defaults)

        #expect(report == SubjectSeeder.Report(inserted: 16, merged: 0))
        let all = try subjects()
        #expect(all.count == 16)
        #expect(all.filter { $0.kind == .general }.count == 10)
        #expect(all.filter { $0.kind == .vocational }.count == 6)
        #expect(Set(all.map(\.name)) == Set(SubjectCatalog.defaultSubjects.map(\.name)))
    }

    @Test("Ponowne uruchomienie niczego nie dodaje")
    func runIsIdempotent() throws {
        try SubjectSeeder.run(in: context, defaults: defaults)
        let second = try SubjectSeeder.run(in: context, defaults: defaults)

        #expect(second == SubjectSeeder.Report(inserted: 0, merged: 0))
        #expect(try subjects().count == 16)
    }

    @Test("Nowa instalacja przy istniejących danych nie tworzy duplikatów")
    func reinstallDoesNotDuplicate() throws {
        try SubjectSeeder.run(in: context, defaults: defaults)

        let freshInstall = try #require(UserDefaults(suiteName: "SubjectSeederTests.\(UUID().uuidString)"))
        let report = try SubjectSeeder.run(in: context, defaults: freshInstall)

        #expect(report.inserted == 0)
        #expect(try subjects().count == 16)
    }

    @Test("Przedmiot usunięty przez użytkowniczkę nie wraca")
    func deletedSubjectIsNotReseeded() throws {
        try SubjectSeeder.run(in: context, defaults: defaults)
        let edb = try #require(try subjects().first { $0.name == "EDB" })
        context.delete(edb)
        try context.save()

        try SubjectSeeder.run(in: context, defaults: defaults)
        #expect(try subjects().count == 15)
    }

    @Test("Listy wgrane na dwóch urządzeniach scalają się do 16, zostają starsze rekordy")
    func mergesListsSeededOnTwoDevices() throws {
        // Pierwsze urządzenie.
        try SubjectSeeder.run(in: context, defaults: defaults)
        let firstDevice = try subjects()
        for subject in firstDevice {
            subject.createdAt = Date(timeIntervalSince1970: 1_000)
        }
        try context.save()
        let firstDeviceIDs = Set(firstDevice.map(\.id))

        // Drugie urządzenie wgrało tę samą listę później, zanim się zsynchronizowało.
        for (index, seed) in SubjectCatalog.defaultSubjects.enumerated() {
            let copy = Subject(name: seed.name, kind: seed.kind, colorName: seed.colorName, iconName: seed.iconName, sortOrder: index)
            context.insert(copy)
            copy.createdAt = Date(timeIntervalSince1970: 2_000)
        }
        try context.save()
        #expect(try subjects().count == 32)

        let report = try SubjectSeeder.run(in: context, defaults: defaults)

        #expect(report.merged == 16)
        let remaining = try subjects()
        #expect(remaining.count == 16)
        #expect(Set(remaining.map(\.id)) == firstDeviceIDs)
    }

    @Test("Wybór zachowanego rekordu nie zależy od kolejności (remis createdAt)")
    func survivorChoiceIsDeterministic() throws {
        let sameDate = Date(timeIntervalSince1970: 5_000)
        var ids: [UUID] = []
        for _ in 0..<3 {
            let subject = Subject(name: "Fizyka", kind: .general, colorName: "ocean", iconName: "atom")
            context.insert(subject)
            subject.createdAt = sameDate
            ids.append(subject.id)
        }
        try context.save()

        try SubjectSeeder.mergeDuplicates(in: context)
        try context.save()

        let remaining = try subjects()
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == ids.min { $0.uuidString < $1.uuidString })
    }

    @Test("Scalanie przenosi sprawdziany i materiały do zachowanego przedmiotu")
    func mergeMovesRelationships() throws {
        let original = Subject(name: "Historia", kind: .general, colorName: "sunflower", iconName: "building.columns.fill")
        let duplicate = Subject(name: "  historia ", kind: .general, colorName: "sunflower", iconName: "building.columns.fill")
        let assessment = Assessment(kind: .test)
        let material = StudyMaterial(kind: .note, title: "Średniowiecze")
        context.insert(original)
        context.insert(duplicate)
        context.insert(assessment)
        context.insert(material)
        original.createdAt = Date(timeIntervalSince1970: 1)
        duplicate.createdAt = Date(timeIntervalSince1970: 2)
        assessment.subject = duplicate
        material.subject = duplicate
        try context.save()

        let removed = try SubjectSeeder.mergeDuplicates(in: context)
        try context.save()

        #expect(removed == 1)
        #expect(try subjects().map(\.id) == [original.id])
        #expect(assessment.subject?.id == original.id)
        #expect(material.subject?.id == original.id)
    }

    @Test("Nazwy, kolory i ikony z listy startowej są poprawne")
    func catalogIsConsistent() {
        let seeds = SubjectCatalog.defaultSubjects
        #expect(seeds.count == 16)
        #expect(Set(seeds.map { SubjectCatalog.normalizedKey($0.name) }).count == 16, "zduplikowana nazwa")

        let paletteNames = Set(SubjectPalette.allCases.map(\.rawValue))
        #expect(Set(seeds.map(\.colorName)) == paletteNames, "każdy przedmiot ma inny kolor z palety")

        for seed in seeds {
            #expect(UIImage(systemName: seed.iconName) != nil, "brak symbolu \(seed.iconName)")
        }
    }

    @Test("Rozpoznaje przedmioty z listy startowej")
    func recognisesDefaultSubjects() {
        #expect(SubjectCatalog.containsDefault(named: "Matematyka"))
        #expect(SubjectCatalog.containsDefault(named: " jezyk polski "))
        #expect(!SubjectCatalog.containsDefault(named: "Test synchronizacji · iPad · 12:00:00"))
    }
}

@MainActor
@Suite("Repozytorium przedmiotów")
struct SubjectRepositoryTests {
    @Test("Nowy przedmiot trafia na koniec listy")
    func addAppendsAtEnd() throws {
        let container = try Persistence.makeInMemoryContainer()
        let context = ModelContext(container)
        try SubjectSeeder.insertMissingDefaults(in: context)
        try context.save()

        let repository = SubjectRepository(context: context)
        let added = try repository.addSubject(name: "Test", kind: .general, colorName: "slate", iconName: "star")

        let all = try repository.allSubjects()
        #expect(all.count == 17)
        #expect(all.last?.id == added.id)
        #expect(added.sortOrder == 16)

        try repository.delete(added)
        #expect(try repository.allSubjects().count == 16)
    }
}

@Suite("System wizualny")
struct DesignSystemTests {
    @Test("Katalog kolorów zawiera kolory semantyczne i 16 kolorów przedmiotów")
    func colorAssetsExist() {
        let bundle = DesignSystemResources.bundle
        for name in Palette.semanticAssetNames {
            #expect(UIColor(named: name, in: bundle, compatibleWith: nil) != nil, "brak koloru \(name)")
        }
        #expect(SubjectPalette.allCases.count == 16)
        for color in SubjectPalette.allCases {
            #expect(UIColor(named: color.assetName, in: bundle, compatibleWith: nil) != nil, "brak koloru \(color.assetName)")
        }
    }

    @Test("Kolory mają osobny wariant ciemny")
    func colorsHaveDarkVariants() throws {
        let bundle = DesignSystemResources.bundle
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        for name in ["Background", "Surface", "TextPrimary"] {
            let color = try #require(UIColor(named: name, in: bundle, compatibleWith: nil))
            #expect(color.resolvedColor(with: light) != color.resolvedColor(with: dark), "\(name) bez trybu ciemnego")
        }
    }
}
