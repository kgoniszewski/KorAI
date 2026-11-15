import Foundation

// Typy wyliczeniowe są zapisywane w bazie jako `String` (pole `...Raw` w encji).
// Wartości `rawValue` trafiają do CloudKit, więc nigdy ich nie zmieniamy:
// nowe przypadki wolno tylko dopisywać.

/// Typ przedmiotu: ogólny lub zawodowy.
public enum SubjectKind: String, CaseIterable, Codable, Sendable {
    case general
    case vocational
}

/// Rodzaj sprawdzianu wiedzy.
public enum AssessmentKind: String, CaseIterable, Codable, Sendable {
    /// Kartkówka.
    case shortQuiz
    /// Sprawdzian.
    case test
    /// Praca klasowa.
    case classTest
    /// Inne.
    case other
}

/// Stan sprawdzianu.
public enum AssessmentStatus: String, CaseIterable, Codable, Sendable {
    case upcoming
    case completed
    case cancelled
}

/// Rodzaj materiału.
public enum MaterialKind: String, CaseIterable, Codable, Sendable {
    case note
    case photo
    case pdf
}

/// Źródło treści (np. talii fiszek).
public enum ContentSource: String, CaseIterable, Codable, Sendable {
    case ai
    case manual
}

/// Poziom trudności quizu.
public enum QuizDifficulty: String, CaseIterable, Codable, Sendable {
    case easy
    case medium
    case hard
}

/// Rodzaj sesji nauki.
public enum StudySessionKind: String, CaseIterable, Codable, Sendable {
    case quiz
    case flashcards
    case reading
    case chat
}

/// Autor wiadomości w czacie.
public enum ChatRole: String, CaseIterable, Codable, Sendable {
    case user
    case assistant
}

/// Stan wymiany monet na nagrodę.
public enum RedemptionStatus: String, CaseIterable, Codable, Sendable {
    /// Zgłoszona.
    case requested
    /// Zatwierdzona.
    case approved
    /// Odebrana.
    case collected
    /// Odrzucona.
    case rejected
}
