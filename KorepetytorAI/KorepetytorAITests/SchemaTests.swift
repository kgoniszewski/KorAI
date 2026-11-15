import CoreData
import Core
import Foundation
import SwiftData
import Testing

@MainActor
@Suite("Schemat danych")
struct SchemaTests {
    private static let expectedEntityNames: Set<String> = [
        "Subject", "Assessment", "StudyMaterial", "FlashcardDeck", "Flashcard",
        "Quiz", "QuizAttempt", "StudySession", "ChatThread", "ChatMessage",
        "XPEvent", "Badge", "Reward", "RewardRedemption", "Profile",
    ]

    @Test("Kontener w pamięci zawiera wszystkie 15 encji")
    func inMemoryContainerHasAllEntities() throws {
        #expect(SchemaV1.models.count == 15)
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))

        let container = try Persistence.makeInMemoryContainer()
        let names = Set(container.schema.entities.map(\.name))
        #expect(names == Self.expectedEntityNames)
    }

    @Test("Każda encja ma id, createdAt i updatedAt")
    func everyModelIsTimestamped() {
        for model in SchemaV1.models {
            #expect(model is any TimestampedModel.Type, "\(model) nie ma wspólnych pól")
        }
    }

    @Test("Schemat spełnia reguły CloudKit")
    func schemaSatisfiesCloudKitRules() throws {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models))
        #expect(Set(model.entities.compactMap(\.name)) == Self.expectedEntityNames)

        for entity in model.entities {
            let entityName = entity.name ?? "?"
            #expect(entity.uniquenessConstraints.isEmpty, "\(entityName): CloudKit nie obsługuje atrybutów unikalnych")

            for (name, attribute) in entity.attributesByName {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entityName).\(name): brak wartości domyślnej"
                )
            }

            for (name, relationship) in entity.relationshipsByName {
                #expect(relationship.isOptional, "\(entityName).\(name): relacja musi być opcjonalna")
                #expect(relationship.inverseRelationship != nil, "\(entityName).\(name): brak relacji odwrotnej")
                #expect(relationship.deleteRule != .denyDeleteRule, "\(entityName).\(name): reguła .deny")
                #expect(!relationship.isOrdered, "\(entityName).\(name): CloudKit nie obsługuje relacji uporządkowanych")
            }
        }
    }

    @Test("Plik materiału jest przechowywany zewnętrznie")
    func materialFileUsesExternalStorage() throws {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models))
        let entity = try #require(model.entitiesByName["StudyMaterial"])
        let fileData = try #require(entity.attributesByName["fileData"])
        #expect(fileData.allowsExternalBinaryDataStorage)
    }

    @Test("Zapis i odczyt każdej encji")
    func savesAndReadsEveryEntity() throws {
        let container = try Persistence.makeInMemoryContainer()
        let writer = ModelContext(container)
        _ = SampleGraph.insert(into: writer)
        try writer.save()

        let reader = ModelContext(container)
        for model in SchemaV1.models {
            try expectCount(of: model, in: reader, equals: 1)
        }

        let assessment = try firstRecord(of: Assessment.self, in: reader)
        #expect(assessment.kind == .shortQuiz)
        #expect(assessment.scope == "Komórka roślinna")
        #expect(assessment.status == .upcoming)

        let material = try firstRecord(of: StudyMaterial.self, in: reader)
        #expect(material.kind == .pdf)
        #expect(material.fileData == Data([0x25, 0x50, 0x44, 0x46]))

        let card = try firstRecord(of: Flashcard.self, in: reader)
        #expect(card.easeFactor == 2.5)
        #expect(card.intervalDays == 0)
        #expect(card.repetitions == 0)

        let redemption = try firstRecord(of: RewardRedemption.self, in: reader)
        #expect(redemption.status == .requested)
        #expect(redemption.coinCost == 100)

        let profile = try firstRecord(of: Profile.self, in: reader)
        #expect(profile.nickname == "Ola")
        #expect(profile.dayOffTokens == 1)
    }

    @Test("Relacje odwrotne są uzupełniane")
    func inverseRelationshipsArePopulated() throws {
        let container = try Persistence.makeInMemoryContainer()
        let writer = ModelContext(container)
        let graph = SampleGraph.insert(into: writer)
        try writer.save()

        let reader = ModelContext(container)
        let subject = try firstRecord(of: Subject.self, in: reader)
        let assessment = try firstRecord(of: Assessment.self, in: reader)
        let material = try firstRecord(of: StudyMaterial.self, in: reader)
        let deck = try firstRecord(of: FlashcardDeck.self, in: reader)
        let quiz = try firstRecord(of: Quiz.self, in: reader)
        let thread = try firstRecord(of: ChatThread.self, in: reader)
        let profile = try firstRecord(of: Profile.self, in: reader)
        let reward = try firstRecord(of: Reward.self, in: reader)

        #expect(subject.assessments.ids == [graph.assessment.id])
        #expect(subject.materials.ids == [graph.material.id])
        #expect(assessment.materials.ids == [graph.material.id])
        #expect(assessment.studySessions.ids == [graph.session.id])
        #expect(assessment.quizzes.ids == [graph.quiz.id])
        #expect(assessment.chatThreads.ids == [graph.thread.id])
        #expect(material.assessments.ids == [graph.assessment.id])
        #expect(material.flashcardDecks.ids == [graph.deck.id])
        #expect(material.quizzes.ids == [graph.quiz.id])
        #expect(material.chatThreads.ids == [graph.thread.id])
        #expect(deck.cards.ids == [graph.card.id])
        #expect(quiz.attempts.ids == [graph.attempt.id])
        #expect(thread.messages.ids == [graph.message.id])
        #expect(profile.xpEvents.ids == [graph.xpEvent.id])
        #expect(profile.badges.ids == [graph.badge.id])
        #expect(reward.redemptions.ids == [graph.redemption.id])
    }

    @Test("Reguły usuwania: kaskada dla elementów podrzędnych, zerowanie dla reszty")
    func deleteRules() throws {
        let container = try Persistence.makeInMemoryContainer()
        let context = ModelContext(container)
        let graph = SampleGraph.insert(into: context)
        try context.save()

        context.delete(graph.deck)
        context.delete(graph.quiz)
        context.delete(graph.thread)
        context.delete(graph.subject)
        context.delete(graph.reward)
        try context.save()

        // Kaskada.
        try expectCount(of: Flashcard.self, in: context, equals: 0)
        try expectCount(of: QuizAttempt.self, in: context, equals: 0)
        try expectCount(of: ChatMessage.self, in: context, equals: 0)
        // Zerowanie: sprawdzian, materiał i historia wymian zostają.
        try expectCount(of: Assessment.self, in: context, equals: 1)
        try expectCount(of: StudyMaterial.self, in: context, equals: 1)
        try expectCount(of: RewardRedemption.self, in: context, equals: 1)
        let assessment = try firstRecord(of: Assessment.self, in: context)
        #expect(assessment.subject == nil)

        // Sesje planu nauki znikają razem ze sprawdzianem.
        context.delete(assessment)
        try context.save()
        try expectCount(of: StudySession.self, in: context, equals: 0)
    }

    @Test("Typy wyliczeniowe zapisują się jako tekst, z bezpiecznym odczytem")
    func enumsRoundTripThroughRawStrings() {
        let assessment = Assessment(kind: .classTest)
        #expect(assessment.kindRaw == "classTest")
        assessment.kindRaw = "nieznany"
        #expect(assessment.kind == .other)
        assessment.kind = .shortQuiz
        #expect(assessment.kindRaw == "shortQuiz")

        let material = StudyMaterial(kind: .photo)
        #expect(material.kindRaw == "photo")
        material.kindRaw = ""
        #expect(material.kind == .note)

        let redemption = RewardRedemption(status: .approved)
        #expect(redemption.statusRaw == "approved")
        redemption.statusRaw = "???"
        #expect(redemption.status == .requested)
    }

    /// Wartości trafiają do CloudKit; zmiana którejkolwiek rozjechałaby dane między urządzeniami.
    @Test("Wartości typów wyliczeniowych są stałe")
    func enumRawValuesAreStable() {
        #expect(SubjectKind.allCases.map(\.rawValue) == ["general", "vocational"])
        #expect(AssessmentKind.allCases.map(\.rawValue) == ["shortQuiz", "test", "classTest", "other"])
        #expect(AssessmentStatus.allCases.map(\.rawValue) == ["upcoming", "completed", "cancelled"])
        #expect(MaterialKind.allCases.map(\.rawValue) == ["note", "photo", "pdf"])
        #expect(ContentSource.allCases.map(\.rawValue) == ["ai", "manual"])
        #expect(QuizDifficulty.allCases.map(\.rawValue) == ["easy", "medium", "hard"])
        #expect(StudySessionKind.allCases.map(\.rawValue) == ["quiz", "flashcards", "reading", "chat"])
        #expect(ChatRole.allCases.map(\.rawValue) == ["user", "assistant"])
        #expect(RedemptionStatus.allCases.map(\.rawValue) == ["requested", "approved", "collected", "rejected"])
    }
}

@Suite("Konfiguracja bazy")
struct PersistenceTests {
    @Test("Rozpoznaje poprawny identyfikator kontenera")
    func validatesContainerIdentifier() {
        #expect(Persistence.isValidContainerIdentifier("iCloud.pl.example.korepetytorai"))
        #expect(!Persistence.isValidContainerIdentifier(""))
        #expect(!Persistence.isValidContainerIdentifier("iCloud."))
        #expect(!Persistence.isValidContainerIdentifier("pl.example.korepetytorai"))
        #expect(!Persistence.isValidContainerIdentifier("$(CLOUDKIT_CONTAINER_IDENTIFIER)"))
        #expect(!Persistence.isValidContainerIdentifier("iCloud.$(KOR_BUNDLE_ID)"))
    }

    @Test("Tryb w pamięci nie używa CloudKit")
    func inMemorySetup() {
        let setup = Persistence.makeAppSetup(
            containerIdentifier: "iCloud.pl.example.korepetytorai",
            inMemory: true,
            initializeSchema: false
        )
        #expect(setup.mode == .inMemory)
        #expect(setup.mode.cloudKitContainerIdentifier == nil)
        #expect(StoreMode.cloudKit(containerIdentifier: "iCloud.x").cloudKitContainerIdentifier == "iCloud.x")
    }
}
