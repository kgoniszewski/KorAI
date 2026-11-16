import SwiftUI

/// Osiem awatarów do wyboru: symbol SF Symbols na kolorowym tle.
/// `rawValue` jest zapisywany w `Profile.avatarID`, więc nazw nie zmieniamy.
public enum AvatarID: String, CaseIterable, Identifiable, Sendable {
    case cat, dog, hare, bird, fish, tortoise, ladybug, lizard

    public var id: String { rawValue }

    /// Awatar dla nieznanego lub pustego identyfikatora.
    public static let fallback: AvatarID = .cat

    /// Awatar o podanym identyfikatorze albo `fallback`.
    public static func resolve(_ rawValue: String) -> AvatarID {
        AvatarID(rawValue: rawValue) ?? fallback
    }

    public var systemImage: String {
        switch self {
        case .cat: "cat.fill"
        case .dog: "dog.fill"
        case .hare: "hare.fill"
        case .bird: "bird.fill"
        case .fish: "fish.fill"
        case .tortoise: "tortoise.fill"
        case .ladybug: "ladybug.fill"
        case .lizard: "lizard.fill"
        }
    }

    /// Kolor tła z palety przedmiotów.
    public var palette: SubjectPalette {
        switch self {
        case .cat: .tangerine
        case .dog: .cocoa
        case .hare: .violet
        case .bird: .sky
        case .fish: .teal
        case .tortoise: .emerald
        case .ladybug: .rose
        case .lizard: .lime
        }
    }
}

/// Awatar w kole: biały symbol na kolorze z palety.
public struct AvatarView: View {
    private let avatar: AvatarID
    private let size: CGFloat

    public init(_ avatar: AvatarID, size: CGFloat = 56) {
        self.avatar = avatar
        self.size = size
    }

    public init(avatarID: String, size: CGFloat = 56) {
        self.init(AvatarID.resolve(avatarID), size: size)
    }

    public var body: some View {
        Image(systemName: avatar.systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(Palette.accentForeground)
            .frame(width: size, height: size)
            .background(avatar.palette.color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

#Preview("Jasny") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.l) {
        ForEach(AvatarID.allCases) { avatar in
            AvatarView(avatar, size: 64)
        }
    }
    .padding(Spacing.xl)
    .background(Palette.background)
}

#Preview("Ciemny") {
    AvatarView(.ladybug, size: 96)
        .padding(Spacing.xl)
        .background(Palette.background)
        .preferredColorScheme(.dark)
}
