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
    /// Gdy profili jest więcej, scala je i zapisuje.
    /// `nil`, gdy profilu jeszcze nie ma (pierwsze uruchomienie).
    ///
    /// Scala i zapisuje dane, więc nie wywołuj go w `body` widoku; widoki czytają profil przez `@Query`.
    public func currentProfile() throws -> Profile? {
        try mergeDuplicates()
        if context.hasChanges {
            try context.save()
        }
        return try allProfiles().first
    }

    /// Scala zduplikowane profile. Nie zapisuje.
    ///
    /// Dwa urządzenia mogą utworzyć profil, zanim się zsynchronizują. Zostaje najstarszy
    /// (`createdAt`, przy remisie najmniejsze `id.uuidString`), więc każde urządzenie
    /// wybiera ten sam rekord niezależnie od kolejności synchronizacji. Wpisy `xpEvents`
    /// i `badges` usuwanych profili przechodzą do zachowanego, a jego puste
    /// `settingsJSON` jest uzupełniane z najstarszego duplikatu, który je ma.
    /// Pseudonim i awatar zostają z zachowanego profilu.
    ///
    /// - Returns: liczba usuniętych duplikatów (0 przy ponownym wywołaniu — operacja jest idempotentna).
    @discardableResult
    public func mergeDuplicates() throws -> Int {
        let profiles = try allProfiles()
        guard let survivor = profiles.first, profiles.count > 1 else { return 0 }

        var removed = 0
        for duplicate in profiles.dropFirst() {
            for event in duplicate.xpEvents ?? [] {
                event.profile = survivor
            }
            for badge in duplicate.badges ?? [] {
                badge.profile = survivor
            }
            if survivor.settingsJSON == nil, let settings = duplicate.settingsJSON {
                survivor.settingsJSON = settings
            }
            context.delete(duplicate)
            removed += 1
        }
        survivor.touch()
        return removed
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
