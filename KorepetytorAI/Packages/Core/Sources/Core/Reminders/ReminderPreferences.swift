import Foundation

/// Przełącznik przypomnienia dla poszczególnych sprawdzianów, zapisany lokalnie na urządzeniu.
///
/// `Assessment` w `SchemaV1` nie ma pola na ten przełącznik, a zmiana schematu w M1
/// byłaby ryzykowna (CloudKit, plan migracji). Każde urządzenie i tak planuje
/// przypomnienia samodzielnie (decyzja 13.1), więc ustawienie jest lokalne.
/// Domyślnie przypomnienie jest włączone; zapisujemy tylko wyłączone.
public struct ReminderPreferences {
    /// Klucz w `UserDefaults` z identyfikatorami sprawdzianów z wyłączonym przypomnieniem.
    public static let disabledIDsKey = "reminders.disabledAssessmentIDs"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Identyfikatory sprawdzianów z wyłączonym przypomnieniem.
    public var disabledIDs: Set<UUID> {
        let strings = defaults.stringArray(forKey: Self.disabledIDsKey) ?? []
        return Set(strings.compactMap(UUID.init(uuidString:)))
    }

    public func isEnabled(for assessmentID: UUID) -> Bool {
        !disabledIDs.contains(assessmentID)
    }

    public func setEnabled(_ isEnabled: Bool, for assessmentID: UUID) {
        var ids = disabledIDs
        if isEnabled {
            ids.remove(assessmentID)
        } else {
            ids.insert(assessmentID)
        }
        store(ids)
    }

    /// Usuwa wpisy sprawdzianów, których już nie ma (np. usuniętych na innym urządzeniu).
    public func removeEntries(notIn existingIDs: Set<UUID>) {
        let ids = disabledIDs
        let kept = ids.intersection(existingIDs)
        if kept != ids {
            store(kept)
        }
    }

    private func store(_ ids: Set<UUID>) {
        if ids.isEmpty {
            defaults.removeObject(forKey: Self.disabledIDsKey)
        } else {
            defaults.set(ids.map(\.uuidString).sorted(), forKey: Self.disabledIDsKey)
        }
    }
}
