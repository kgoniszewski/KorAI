import SwiftUI

/// Kolory semantyczne. Każdy ma wariant jasny i ciemny w `Colors.xcassets`.
public enum Palette {
    public static var background: Color { Color("Background", bundle: .module) }
    public static var surface: Color { Color("Surface", bundle: .module) }
    public static var textPrimary: Color { Color("TextPrimary", bundle: .module) }
    public static var textSecondary: Color { Color("TextSecondary", bundle: .module) }
    public static var accent: Color { Color("Accent", bundle: .module) }
    /// Tekst i ikony na tle akcentu.
    public static var accentForeground: Color { Color("AccentForeground", bundle: .module) }
    /// Drugi kolor gradientu akcentu.
    public static var highlight: Color { Color("Highlight", bundle: .module) }

    /// Gradient głównych przycisków i wyróżnień.
    public static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, highlight], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Nazwy zasobów kolorów semantycznych (do testów kompletności katalogu).
    public static let semanticAssetNames = [
        "Background", "Surface", "TextPrimary", "TextSecondary", "Accent", "AccentForeground", "Highlight",
    ]
}

/// Paleta 16 kolorów przedmiotów. `rawValue` jest zapisywany w `Subject.colorName`,
/// więc nazw nie zmieniamy.
public enum SubjectPalette: String, CaseIterable, Sendable {
    case rose, coral, tangerine, sunflower
    case lime, emerald, mint, teal
    case sky, ocean, indigo, violet
    case magenta, berry, cocoa, slate

    /// Nazwa zasobu w `Colors.xcassets`, np. `SubjectRose`.
    public var assetName: String {
        "Subject" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    public var color: Color { Color(assetName, bundle: .module) }

    /// Kolor przedmiotu o podanej nazwie; nieznana nazwa daje kolor akcentu.
    public static func color(named name: String) -> Color {
        SubjectPalette(rawValue: name)?.color ?? Palette.accent
    }
}

/// Dostęp do zasobów pakietu (np. w testach).
public enum DesignSystemResources {
    public static var bundle: Bundle { .module }
}
