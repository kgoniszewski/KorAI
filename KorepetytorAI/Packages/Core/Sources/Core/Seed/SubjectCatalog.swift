import Foundation

/// Opis przedmiotu wgrywanego na start.
public struct SubjectSeed: Equatable, Sendable {
    public let name: String
    public let kind: SubjectKind
    /// Nazwa koloru z palety przedmiotów w `DesignSystem` (`SubjectPalette`).
    public let colorName: String
    /// Symbol SF Symbols.
    public let iconName: String

    public init(name: String, kind: SubjectKind, colorName: String, iconName: String) {
        self.name = name
        self.kind = kind
        self.colorName = colorName
        self.iconName = iconName
    }
}

/// 16 przedmiotów z bieżącego roku szkolnego (10 ogólnych, 6 zawodowych).
public enum SubjectCatalog {
    public static let defaultSubjects: [SubjectSeed] = [
        // Ogólne
        SubjectSeed(name: "Język polski", kind: .general, colorName: "rose", iconName: "book.closed.fill"),
        SubjectSeed(name: "Język angielski", kind: .general, colorName: "sky", iconName: "character.bubble.fill"),
        SubjectSeed(name: "Język francuski", kind: .general, colorName: "indigo", iconName: "quote.bubble.fill"),
        SubjectSeed(name: "Matematyka", kind: .general, colorName: "violet", iconName: "function"),
        SubjectSeed(name: "Biologia", kind: .general, colorName: "emerald", iconName: "leaf.fill"),
        SubjectSeed(name: "Historia", kind: .general, colorName: "sunflower", iconName: "building.columns.fill"),
        SubjectSeed(name: "Biznes i zarządzanie", kind: .general, colorName: "teal", iconName: "briefcase.fill"),
        SubjectSeed(name: "Fizyka", kind: .general, colorName: "ocean", iconName: "atom"),
        SubjectSeed(name: "Informatyka", kind: .general, colorName: "lime", iconName: "laptopcomputer"),
        SubjectSeed(name: "EDB", kind: .general, colorName: "coral", iconName: "cross.case.fill"),
        // Zawodowe
        SubjectSeed(name: "Podstawy hotelarstwa", kind: .vocational, colorName: "magenta", iconName: "building.2.fill"),
        SubjectSeed(name: "Język francuski zawodowy", kind: .vocational, colorName: "berry", iconName: "bubble.left.and.bubble.right.fill"),
        SubjectSeed(name: "Organizacja pracy w hotelarstwie", kind: .vocational, colorName: "tangerine", iconName: "list.bullet.clipboard.fill"),
        SubjectSeed(name: "Usługi żywieniowe", kind: .vocational, colorName: "cocoa", iconName: "fork.knife"),
        SubjectSeed(name: "Techniki pracy w hotelarstwie", kind: .vocational, colorName: "slate", iconName: "bed.double.fill"),
        SubjectSeed(name: "Pracownia obsługi gościa", kind: .vocational, colorName: "mint", iconName: "key.fill"),
    ]

    /// Klucz porównania nazw: bez wielkości liter, polskich znaków i skrajnych spacji.
    public static func normalizedKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pl_PL"))
    }

    /// Czy przedmiot o tej nazwie pochodzi z listy startowej.
    public static func containsDefault(named name: String) -> Bool {
        let key = normalizedKey(name)
        return defaultSubjects.contains { normalizedKey($0.name) == key }
    }
}
