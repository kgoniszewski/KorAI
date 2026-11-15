import Core
import Foundation
import SwiftData

typealias Subject = Core.Subject

/// Liczba rekordów danego typu (otwiera egzystencjalny typ modelu).
func recordCount<Model: PersistentModel>(of type: Model.Type, in context: ModelContext) throws -> Int {
    try context.fetchCount(FetchDescriptor<Model>())
}

/// Każda z 15 encji wstawiona dokładnie raz i połączona wszystkimi relacjami.
struct SampleGraph {
    let subject: Subject
    let assessment: Assessment
    let material: StudyMaterial
    let deck: FlashcardDeck
    let card: Flashcard
    let quiz: Quiz
    let attempt: QuizAttempt
    let session: StudySession
    let thread: ChatThread
    let message: ChatMessage
    let xpEvent: XPEvent
    let badge: Badge
    let reward: Reward
    let redemption: RewardRedemption
    let profile: Profile

    static func insert(into context: ModelContext) -> SampleGraph {
        let graph = SampleGraph(
            subject: Subject(name: "Biologia", kind: .general, colorName: "emerald", iconName: "leaf.fill"),
            assessment: Assessment(kind: .shortQuiz, date: .now.addingTimeInterval(86_400), scope: "Komórka roślinna"),
            material: StudyMaterial(kind: .pdf, title: "Komórka", content: "", fileData: Data([0x25, 0x50, 0x44, 0x46])),
            deck: FlashcardDeck(title: "Organelle", source: .ai),
            card: Flashcard(front: "Mitochondrium", back: "Centrum energetyczne komórki"),
            quiz: Quiz(title: "Quiz: komórka", questionsJSON: Data("[]".utf8), difficulty: .easy),
            attempt: QuizAttempt(score: 0.9),
            session: StudySession(durationMinutes: 15, kind: .flashcards),
            thread: ChatThread(title: "Pytania o komórkę"),
            message: ChatMessage(role: .assistant, content: "Od czego zaczniemy?"),
            xpEvent: XPEvent(reason: "session", xp: 20, coins: 2),
            badge: Badge(badgeID: "quiz-perfect-first"),
            reward: Reward(name: "Kino", coinCost: 100),
            redemption: RewardRedemption(status: .requested, coinCost: 100),
            profile: Profile(nickname: "Ola", avatarID: "fox", dayOffTokens: 1)
        )

        let all: [any PersistentModel] = [
            graph.subject, graph.assessment, graph.material, graph.deck, graph.card,
            graph.quiz, graph.attempt, graph.session, graph.thread, graph.message,
            graph.xpEvent, graph.badge, graph.reward, graph.redemption, graph.profile,
        ]
        for model in all {
            context.insert(model)
        }

        graph.assessment.subject = graph.subject
        graph.material.subject = graph.subject
        graph.material.assessments = [graph.assessment]
        graph.deck.material = graph.material
        graph.card.deck = graph.deck
        graph.quiz.material = graph.material
        graph.quiz.assessment = graph.assessment
        graph.attempt.quiz = graph.quiz
        graph.session.assessment = graph.assessment
        graph.thread.material = graph.material
        graph.thread.assessment = graph.assessment
        graph.message.thread = graph.thread
        graph.xpEvent.profile = graph.profile
        graph.badge.profile = graph.profile
        graph.redemption.reward = graph.reward
        return graph
    }
}

extension Optional where Wrapped: Collection, Wrapped.Element: TimestampedModel {
    /// Identyfikatory elementów opcjonalnej relacji.
    var ids: Set<UUID> {
        guard let collection = self else { return [] }
        return Set(collection.map(\.id))
    }
}
