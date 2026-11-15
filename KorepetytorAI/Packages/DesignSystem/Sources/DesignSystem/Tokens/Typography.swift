import SwiftUI

/// Typografia oparta na stylach systemowych, więc skaluje się z Dynamic Type.
/// Krój zaokrąglony nadaje lżejszy, mniej „dziennikowy” charakter.
public enum Typography {
    public static var display: Font { .system(.largeTitle, design: .rounded, weight: .heavy) }
    public static var title: Font { .system(.title2, design: .rounded, weight: .bold) }
    public static var headline: Font { .system(.headline, design: .rounded, weight: .semibold) }
    public static var body: Font { .system(.body, design: .rounded) }
    public static var callout: Font { .system(.callout, design: .rounded) }
    public static var caption: Font { .system(.caption, design: .rounded, weight: .medium) }
}

/// Odstępy: 4, 8, 12, 16, 24.
public enum Spacing {
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
}

/// Duże zaokrąglenia.
public enum Radius {
    public static let small: CGFloat = 12
    public static let medium: CGFloat = 20
    public static let large: CGFloat = 28
}
