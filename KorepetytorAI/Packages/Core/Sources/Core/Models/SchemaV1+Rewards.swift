import Foundation
import SwiftData

extension SchemaV1 {
    /// Wpis w dzienniku punktów. Poziom i saldo monet są z niego wyliczane,
    /// więc synchronizacja między urządzeniami nigdy nie gubi punktów.
    @Model
    public final class XPEvent {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var date: Date = Date.now
        /// Powód przyznania punktów (słownik powodów powstaje w M3).
        public var reason: String = ""
        public var xp: Int = 0
        public var coins: Int = 0

        public var profile: Profile?

        public init(date: Date = .now, reason: String = "", xp: Int = 0, coins: Int = 0) {
            self.date = date
            self.reason = reason
            self.xp = xp
            self.coins = coins
        }
    }

    /// Zdobyta odznaka.
    @Model
    public final class Badge {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        /// Stały identyfikator odznaki, np. `quiz-perfect-first`.
        public var badgeID: String = ""
        public var earnedAt: Date = Date.now

        public var profile: Profile?

        public init(badgeID: String = "", earnedAt: Date = .now) {
            self.badgeID = badgeID
            self.earnedAt = earnedAt
        }
    }

    /// Realna nagroda zdefiniowana przez rodzica.
    @Model
    public final class Reward {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var name: String = ""
        public var coinCost: Int = 0
        public var isActive: Bool = true

        /// Usunięcie nagrody nie usuwa historii wymian (saldo monet musi się zgadzać).
        @Relationship(deleteRule: .nullify, inverse: \RewardRedemption.reward)
        public var redemptions: [RewardRedemption]? = []

        public init(name: String = "", coinCost: Int = 0, isActive: Bool = true) {
            self.name = name
            self.coinCost = coinCost
            self.isActive = isActive
        }
    }

    /// Zgłoszenie wymiany monet na nagrodę.
    @Model
    public final class RewardRedemption {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var date: Date = Date.now
        public var statusRaw: String = RedemptionStatus.requested.rawValue
        /// Koszt w chwili zgłoszenia; późniejsza zmiana ceny nagrody nie zmienia salda.
        public var coinCost: Int = 0

        public var reward: Reward?

        public var status: RedemptionStatus {
            get { RedemptionStatus(rawValue: statusRaw) ?? .requested }
            set { statusRaw = newValue.rawValue }
        }

        public init(date: Date = .now, status: RedemptionStatus = .requested, coinCost: Int = 0) {
            self.date = date
            self.statusRaw = status.rawValue
            self.coinCost = coinCost
        }
    }

    /// Profil uczennicy; jeden na konto iCloud.
    @Model
    public final class Profile {
        public var id: UUID = UUID()
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var nickname: String = ""
        public var avatarID: String = ""
        /// Ustawienia w formacie JSON (zawartość ustalają kolejne etapy).
        public var settingsJSON: Data? = nil
        /// Liczba dostępnych „dni wolnych” chroniących serię.
        public var dayOffTokens: Int = 0

        @Relationship(deleteRule: .nullify, inverse: \XPEvent.profile)
        public var xpEvents: [XPEvent]? = []

        @Relationship(deleteRule: .nullify, inverse: \Badge.profile)
        public var badges: [Badge]? = []

        public init(nickname: String = "", avatarID: String = "", dayOffTokens: Int = 0) {
            self.nickname = nickname
            self.avatarID = avatarID
            self.dayOffTokens = dayOffTokens
        }
    }
}
