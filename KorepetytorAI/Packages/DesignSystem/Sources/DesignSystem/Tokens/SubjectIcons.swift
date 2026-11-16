/// Krótka lista symboli SF Symbols do wyboru ikony przedmiotu.
/// Zawiera ikony przedmiotów startowych, więc każdy z nich da się wybrać z powrotem.
public enum SubjectIcons {
    public static let all: [String] = [
        // Przedmioty startowe
        "book.closed.fill", "character.bubble.fill", "quote.bubble.fill", "function",
        "leaf.fill", "building.columns.fill", "briefcase.fill", "atom",
        "laptopcomputer", "cross.case.fill", "building.2.fill", "bubble.left.and.bubble.right.fill",
        "list.bullet.clipboard.fill", "fork.knife", "bed.double.fill", "key.fill",
        // Dodatkowe
        "flask.fill", "globe.europe.africa.fill", "music.note", "paintpalette.fill",
        "figure.run", "pencil.and.ruler.fill", "chart.bar.fill", "cup.and.saucer.fill",
        "suitcase.rolling.fill", "theatermasks.fill", "star.fill", "lightbulb.fill",
    ]

    /// Ikona nowego przedmiotu.
    public static let defaultIcon = "book.closed.fill"
}
