import Foundation
import SwiftData

/// Błędy zapisu profilu.
public enum ProfileRepositoryError: Error, Equatable, Sendable {
    /// Pseudonim jest pusty (po usunięciu spacji).
    case emptyNickname
}

/// Dostęp do profilu uczennicy (jeden na konto iCloud).
public struct ProfileRepository {
    /// Maksymalna długość pseudonimu.
    public static let maxNicknameLength = 30

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Wszystkie profile, od tego, który zostaje przy scalaniu (najstarszy).
    public func allProfiles() throws -> [Profile] {
        try context.fetch(FetchDescriptor<Profile>()).sorted(by: Self.isPreferredSurvivor)
    }

    /// Bieżący profil: najstarszy według `createdAt` (przy remisie najmniejsze `id`).
    /// `nil`, gdy profilu jeszcze nie ma (pierwsze uruchomienie).
    public func currentProfile() throws -> Profile? {
        try allProfiles().first
    }

    /// Tworzy profil i zapisuje. Wywołuje go tylko wprowadzenie, gdy `currentProfile()` zwraca `nil`.
    @discardableResult
    public func createProfile(nickname: String, avatarID: String) throws -> Profile {
        let profile = Profile(nickname: try Self.validatedNickname(nickname), avatarID: avatarID)
        context.insert(profile)
        try context.save()
        return profile
    }

    /// Zmienia pseudonim i awatar i zapisuje.
    public func update(_ profile: Profile, nickname: String, avatarID: String) throws {
        profile.nickname = try Self.validatedNickname(nickname)
        profile.avatarID = avatarID
        profile.touch()
        try context.save()
    }

    // MARK: - Pomocnicze

    /// Pseudonim bez skrajnych spacji, przycięty do `maxNicknameLength` znaków.
    public static func validatedNickname(_ nickname: String) throws -> String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProfileRepositoryError.emptyNickname
        }
        return String(trimmed.prefix(maxNicknameLength))
    }

    /// Kolejność wyboru profilu, który zostaje: najstarszy, przy remisie najmniejsze `id`.
    /// Ta sama reguła co dla przedmiotów, więc każde urządzenie wybiera ten sam rekord.
    public static func isPreferredSurvivor(_ lhs: Profile, _ rhs: Profile) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
