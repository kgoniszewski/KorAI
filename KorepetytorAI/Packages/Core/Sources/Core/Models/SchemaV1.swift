import Foundation
import SwiftData

/// Pierwsza wersja schematu: wszystkie 15 encji z dokumentu architektury.
///
/// Reguły CloudKit obowiązujące w każdej encji:
/// - każda właściwość ma wartość domyślną lub jest opcjonalna,
/// - każda relacja jest opcjonalna i ma jawną relację odwrotną
///   (deklarowaną tylko po jednej stronie),
/// - brak `@Attribute(.unique)` i reguły usuwania `.deny`.
///
/// Zmiany schematu są wyłącznie addytywne; kolejna wersja powstaje jako `SchemaV2`.
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            Subject.self,
            Assessment.self,
            StudyMaterial.self,
            FlashcardDeck.self,
            Flashcard.self,
            Quiz.self,
            QuizAttempt.self,
            StudySession.self,
            ChatThread.self,
            ChatMessage.self,
            XPEvent.self,
            Badge.self,
            Reward.self,
            RewardRedemption.self,
            Profile.self,
        ]
    }
}

/// Plan migracji. W M0 zawiera tylko `SchemaV1` i nie ma etapów.
public enum KorepetytorMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

/// Wspólne pola każdej encji.
public protocol TimestampedModel: AnyObject {
    var id: UUID { get }
    var createdAt: Date { get }
    var updatedAt: Date { get set }
}

extension TimestampedModel {
    /// Oznacza rekord jako zmieniony.
    public func touch() {
        updatedAt = .now
    }
}

// Aktualne nazwy encji. Kod aplikacji używa tych aliasów, a nie `SchemaV1.*`,
// więc kolejna wersja schematu zmienia tylko te linie.
public typealias Subject = SchemaV1.Subject
public typealias Assessment = SchemaV1.Assessment
public typealias StudyMaterial = SchemaV1.StudyMaterial
public typealias FlashcardDeck = SchemaV1.FlashcardDeck
public typealias Flashcard = SchemaV1.Flashcard
public typealias Quiz = SchemaV1.Quiz
public typealias QuizAttempt = SchemaV1.QuizAttempt
public typealias StudySession = SchemaV1.StudySession
public typealias ChatThread = SchemaV1.ChatThread
public typealias ChatMessage = SchemaV1.ChatMessage
public typealias XPEvent = SchemaV1.XPEvent
public typealias Badge = SchemaV1.Badge
public typealias Reward = SchemaV1.Reward
public typealias RewardRedemption = SchemaV1.RewardRedemption
public typealias Profile = SchemaV1.Profile

extension SchemaV1.Subject: TimestampedModel {}
extension SchemaV1.Assessment: TimestampedModel {}
extension SchemaV1.StudyMaterial: TimestampedModel {}
extension SchemaV1.FlashcardDeck: TimestampedModel {}
extension SchemaV1.Flashcard: TimestampedModel {}
extension SchemaV1.Quiz: TimestampedModel {}
extension SchemaV1.QuizAttempt: TimestampedModel {}
extension SchemaV1.StudySession: TimestampedModel {}
extension SchemaV1.ChatThread: TimestampedModel {}
extension SchemaV1.ChatMessage: TimestampedModel {}
extension SchemaV1.XPEvent: TimestampedModel {}
extension SchemaV1.Badge: TimestampedModel {}
extension SchemaV1.Reward: TimestampedModel {}
extension SchemaV1.RewardRedemption: TimestampedModel {}
extension SchemaV1.Profile: TimestampedModel {}
