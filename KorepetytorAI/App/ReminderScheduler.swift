import Core
import Foundation
import OSLog
import SwiftData
import UserNotifications

private let logger = Logger(subsystem: "KorepetytorAI", category: "Reminders")

/// Lokalne przypomnienia o sprawdzianach (`UNUserNotificationCenter`).
///
/// Przypomnienia są zawsze uzgadniane z całą bazą (`sync`): planowane są wszystkie
/// włączone, nadchodzące sprawdziany, a usuwane żądania sprawdzianów usuniętych,
/// zakończonych, odwołanych lub z wyłączonym przełącznikiem. Dzięki temu zmiana daty,
/// przedmiotu, usunięcie i dane z iCloud z innego urządzenia obsługuje jedna ścieżka.
enum ReminderScheduler {
    /// Stan zgody na powiadomienia, uproszczony do potrzeb edytora.
    enum Authorization: Sendable {
        case notDetermined
        case denied
        case authorized
    }

    // MARK: - Zgoda

    static func authorization() async -> Authorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return Authorization(settings.authorizationStatus)
    }

    /// Prosi o zgodę (systemowe okno pojawia się tylko za pierwszym razem).
    /// - Returns: stan zgody po odpowiedzi.
    @discardableResult
    static func requestAuthorization() async -> Authorization {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Prośba o zgodę na powiadomienia nie powiodła się: \(String(describing: error), privacy: .public)")
        }
        return await authorization()
    }

    // MARK: - Planowanie

    /// Uzgadnia oczekujące przypomnienia z bazą. Wywoływane przy starcie, po powrocie
    /// na pierwszy plan, po zmianach z iCloud i po każdej zmianie sprawdzianu.
    @MainActor
    static func sync(context: ModelContext, preferences: ReminderPreferences = ReminderPreferences()) async {
        let candidates: [ReminderCandidate]
        do {
            let repository = AssessmentRepository(context: context)
            let allIDs = Set(try repository.assessments().map(\.id))
            preferences.removeEntries(notIn: allIDs)
            candidates = try repository.allUpcoming().map {
                ReminderCandidate($0, isEnabled: preferences.isEnabled(for: $0.id))
            }
        } catch {
            logger.error("Odczyt sprawdzianów do przypomnień nie powiódł się: \(String(describing: error), privacy: .public)")
            return
        }

        // Wywołania `sync` mogą się nakładać (start, powrót na pierwszy plan, iCloud, zapis),
        // a `apply` ma punkty zawieszenia. Kolejne zastosowania planu idą więc po kolei,
        // w kolejności wywołań: starszy plan nie nadpisze nowszego (np. nie przywróci
        // przypomnienia właśnie usuniętego sprawdzianu).
        let plan = ReminderPlanner.plan(for: candidates)
        let previous = pendingApply
        let current = Task {
            await previous?.value
            await apply(plan)
        }
        pendingApply = current
        await current.value
    }

    /// Ostatnie zlecone zastosowanie planu (kolejka `sync`).
    @MainActor private static var pendingApply: Task<Void, Never>?

    /// Usuwa nieaktualne żądania i dodaje (lub zastępuje) zaplanowane.
    private static func apply(_ plan: [PlannedReminder]) async {
        let center = UNUserNotificationCenter.current()
        let wanted = Set(plan.map(\.identifier))

        let pending = await center.pendingNotificationRequests()
        let stale = pending
            .map(\.identifier)
            .filter { ReminderPlanner.assessmentID(fromIdentifier: $0) != nil && !wanted.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        guard await authorization() == .authorized else { return }

        for request in plan.map(makeRequest) {
            do {
                // Ten sam identyfikator zastępuje wcześniejsze żądanie (np. po zmianie daty).
                try await center.add(request)
            } catch {
                logger.error("Nie udało się zaplanować przypomnienia: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Żądanie powiadomienia: „Jutro: sprawdzian” i nazwa przedmiotu, bez zakresu materiału.
    private static func makeRequest(for reminder: PlannedReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title(for: reminder.kind)
        content.body = reminder.subjectName ?? String(localized: "assessment.noSubject")
        content.sound = .default
        content.threadIdentifier = "assessments"

        // Komponenty daty w kalendarzu urządzenia: godzina 18:00 zostaje 18:00 także po zmianie czasu.
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }

    private static func title(for kind: AssessmentKind) -> String {
        switch kind {
        case .shortQuiz: String(localized: "reminder.title.shortQuiz")
        case .test: String(localized: "reminder.title.test")
        case .classTest: String(localized: "reminder.title.classTest")
        case .other: String(localized: "reminder.title.other")
        }
    }
}

extension ReminderScheduler.Authorization {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized, .provisional, .ephemeral: self = .authorized
        @unknown default: self = .denied
        }
    }
}

/// Pokazuje przypomnienie także wtedy, gdy aplikacja jest na pierwszym planie.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
