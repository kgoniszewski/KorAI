import Foundation
import SwiftData

extension SchemaV1 {
    /// Talia fiszek, ręczna lub wygenerowana przez AI.
    @Model
    public final class FlashcardDeck {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var title: String = ""
        public var sourceRaw: String = ContentSource.manual.rawValue

        public var material: StudyMaterial?

        @Relationship(deleteRule: .cascade, inverse: \Flashcard.deck)
        public var cards: [Flashcard]? = []

        public var source: ContentSource {
            get { ContentSource(rawValue: sourceRaw) ?? .manual }
            set { sourceRaw = newValue.rawValue }
        }

        public init(title: String = "", source: ContentSource = .manual) {
            self.title = title
            self.sourceRaw = source.rawValue
        }
    }

    /// Fiszka z polami algorytmu SM-2.
    @Model
    public final class Flashcard {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var front: String = ""
        public var back: String = ""
        /// Termin następnej powtórki.
        public var dueDate: Date = Date.now
        /// Interwał w dniach.
        public var intervalDays: Int = 0
        /// Współczynnik łatwości SM-2 (startowo 2,5).
        public var easeFactor: Double = 2.5
        /// Liczba kolejnych poprawnych powtórek (SM-2).
        public var repetitions: Int = 0

        public var deck: FlashcardDeck?

        public init(front: String = "", back: String = "", dueDate: Date = .now) {
            self.front = front
            self.back = back
            self.dueDate = dueDate
        }
    }

    /// Quiz z pytaniami zapisanymi jako JSON.
    @Model
    public final class Quiz {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var title: String = ""
        /// Pytania w formacie JSON (schemat ustala M4).
        public var questionsJSON: Data? = nil
        public var difficultyRaw: String = QuizDifficulty.medium.rawValue

        public var material: StudyMaterial?
        public var assessment: Assessment?

        @Relationship(deleteRule: .cascade, inverse: \QuizAttempt.quiz)
        public var attempts: [QuizAttempt]? = []

        public var difficulty: QuizDifficulty {
            get { QuizDifficulty(rawValue: difficultyRaw) ?? .medium }
            set { difficultyRaw = newValue.rawValue }
        }

        public init(title: String = "", questionsJSON: Data? = nil, difficulty: QuizDifficulty = .medium) {
            self.title = title
            self.questionsJSON = questionsJSON
            self.difficultyRaw = difficulty.rawValue
        }
    }

    /// Jedno podejście do quizu.
    @Model
    public final class QuizAttempt {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var date: Date = Date.now
        /// Wynik w zakresie 0...1.
        public var score: Double = 0
        /// Odpowiedzi w formacie JSON.
        public var answersJSON: Data? = nil

        public var quiz: Quiz?

        public init(date: Date = .now, score: Double = 0, answersJSON: Data? = nil) {
            self.date = date
            self.score = score
            self.answersJSON = answersJSON
        }
    }

    /// Zaplanowana sesja nauki (10–15 minut).
    @Model
    public final class StudySession {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var plannedDate: Date = Date.now
        public var durationMinutes: Int = 10
        public var kindRaw: String = StudySessionKind.reading.rawValue
        public var isCompleted: Bool = false

        public var assessment: Assessment?

        public var kind: StudySessionKind {
            get { StudySessionKind(rawValue: kindRaw) ?? .reading }
            set { kindRaw = newValue.rawValue }
        }

        public init(
            plannedDate: Date = .now,
            durationMinutes: Int = 10,
            kind: StudySessionKind = .reading,
            isCompleted: Bool = false
        ) {
            self.plannedDate = plannedDate
            self.durationMinutes = durationMinutes
            self.kindRaw = kind.rawValue
            self.isCompleted = isCompleted
        }
    }
}
