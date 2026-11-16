import Core
import Foundation
import SwiftData
import Testing

@MainActor
@Suite("Repozytorium profilu")
struct ProfileRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let repository: ProfileRepository

    init() throws {
        container = try Persistence.makeInMemoryContainer()
        context = ModelContext(container)
        repository = ProfileRepository(context: context)
    }

    /// Wstawia profil z podaną datą utworzenia (symulacja profilu z innego urządzenia).
    @discardableResult
    private func insertProfile(nickname: String, createdAt: TimeInterval) throws -> Profile {
        let profile = Profile(nickname: nickname, avatarID: "fox")
        context.insert(profile)
        profile.createdAt = Date(timeIntervalSince1970: createdAt)
        try context.save()
        return profile
    }

    @Test("Bez profilu currentProfile zwraca nil")
    func noProfile() throws {
        #expect(try repository.currentProfile() == nil)
    }

    @Test("Utworzenie profilu zapisuje pseudonim i awatar")
    func createProfile() throws {
        let created = try repository.createProfile(nickname: "  Ola ", avatarID: "cat")

        let reader = ProfileRepository(context: ModelContext(container))
        let current = try #require(try reader.currentProfile())
        #expect(current.id == created.id)
        #expect(current.nickname == "Ola")
        #expect(current.avatarID == "cat")
    }

    @Test("Pusty pseudonim jest odrzucany")
    func emptyNicknameIsRejected() throws {
        #expect(throws: ProfileRepositoryError.emptyNickname) {
            try repository.createProfile(nickname: "  ", avatarID: "cat")
        }
        try expectCount(of: Profile.self, in: context, equals: 0)
    }

    @Test("currentProfile zwraca najstarszy profil")
    func currentProfileReturnsOldest() throws {
        try insertProfile(nickname: "Nowszy", createdAt: 2_000)
        let oldest = try insertProfile(nickname: "Najstarszy", createdAt: 1_000)
        try insertProfile(nickname: "Najnowszy", createdAt: 3_000)

        #expect(try repository.currentProfile()?.id == oldest.id)
    }

    @Test("Edycja zmienia pseudonim, awatar i updatedAt")
    func updateProfile() throws {
        let profile = try repository.createProfile(nickname: "Ola", avatarID: "cat")
        let before = Date(timeIntervalSince1970: 1)
        profile.updatedAt = before

        try repository.update(profile, nickname: "Ola K.", avatarID: "owl")

        #expect(profile.nickname == "Ola K.")
        #expect(profile.avatarID == "owl")
        #expect(profile.updatedAt > before)
    }

    @Test("Scalanie dwóch profili przenosi xpEvents i badges i usuwa nadmiarowy")
    func mergeMovesRelationshipsAndRemovesDuplicate() throws {
        let survivor = try insertProfile(nickname: "iPhone", createdAt: 1_000)
        let duplicate = try insertProfile(nickname: "iPad", createdAt: 2_000)
        let survivorEvent = XPEvent(reason: "session", xp: 10)
        let duplicateEvent = XPEvent(reason: "quiz", xp: 20)
        let duplicateBadge = Badge(badgeID: "quiz-perfect-first")
        context.insert(survivorEvent)
        context.insert(duplicateEvent)
        context.insert(duplicateBadge)
        survivorEvent.profile = survivor
        duplicateEvent.profile = duplicate
        duplicateBadge.profile = duplicate
        duplicate.settingsJSON = Data("{}".utf8)
        try context.save()

        let current = try #require(try repository.currentProfile())
        #expect(current.id == survivor.id)

        // Odczyt w nowym kontekście: sprawdza stan zapisany w magazynie.
        let reader = ModelContext(container)
        let profiles = try reader.fetch(FetchDescriptor<Profile>())
        let actual: [UUID] = profiles.map(\.id)
        let expected: [UUID] = [survivor.id]
        #expect(actual == expected)
        let stored = try #require(profiles.first)
        #expect(stored.nickname == "iPhone")
        let actual2: Set<UUID> = stored.xpEvents.ids
        let expected2: Set<UUID> = [survivorEvent.id, duplicateEvent.id]
        #expect(actual2 == expected2)
        let actual3: Set<UUID> = stored.badges.ids
        let expected3: Set<UUID> = [duplicateBadge.id]
        #expect(actual3 == expected3)
        #expect(stored.settingsJSON == Data("{}".utf8))
        try expectCount(of: XPEvent.self, in: reader, equals: 2)
        try expectCount(of: Badge.self, in: reader, equals: 1)
    }

    @Test("Scalanie jest idempotentne")
    func mergeIsIdempotent() throws {
        let survivor = try insertProfile(nickname: "A", createdAt: 1_000)
        try insertProfile(nickname: "B", createdAt: 2_000)
        try insertProfile(nickname: "C", createdAt: 3_000)

        #expect(try repository.mergeDuplicates() == 2)
        try context.save()
        #expect(try repository.mergeDuplicates() == 0)
        #expect(!context.hasChanges)
        let actual: [UUID] = try repository.allProfiles().map(\.id)
        let expected: [UUID] = [survivor.id]
        #expect(actual == expected)
    }

    @Test("Wybór zachowanego profilu nie zależy od kolejności (remis createdAt)")
    func survivorChoiceIsDeterministic() throws {
        var ids: [UUID] = []
        for nickname in ["A", "B", "C"] {
            ids.append(try insertProfile(nickname: nickname, createdAt: 5_000).id)
        }

        try repository.mergeDuplicates()
        try context.save()

        let remaining = try repository.allProfiles()
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == ids.min { $0.uuidString < $1.uuidString })
    }
}
