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
}
