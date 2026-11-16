import CloudKit
import Combine
import CoreData
import Core
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "KorepetytorAI", category: "DataMaintenance")

/// Utrzymanie danych w tle: wgranie przedmiotów, scalanie duplikatów przedmiotów
/// i profili po synchronizacji, przeplanowanie przypomnień oraz odświeżanie stanu konta iCloud.
struct DataMaintenance: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.storeMode) private var storeMode
    @Environment(CloudAccountMonitor.self) private var cloudAccount

    // Potoki tworzone raz: odtwarzanie ich przy każdym przeliczeniu `body`
    // gubiłoby oczekujące zdarzenie w `debounce`.

    /// Zmiany przychodzące z iCloud: po imporcie mogą pojawić się duplikaty
    /// przedmiotów wgranych osobno na drugim urządzeniu.
    private static let remoteChanges = NotificationCenter.default
        .publisher(for: .NSPersistentStoreRemoteChange)
        .debounce(for: .seconds(2), scheduler: DispatchQueue.main)

    private static let accountChanges = NotificationCenter.default
        .publisher(for: .CKAccountChanged)
        .receive(on: DispatchQueue.main)

    func body(content: Content) -> some View {
        content
            .task {
                seedSubjects()
                mergeDuplicateProfiles()
                await ReminderScheduler.sync(context: modelContext)
                await cloudAccount.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    mergeDuplicates()
                    // Także po zmianie zgody w Ustawieniach.
                    Task { await ReminderScheduler.sync(context: modelContext) }
                }
            }
            .onReceive(Self.remoteChanges) { _ in
                // Sprawdziany z innego urządzenia: przypomnienia trzeba zaplanować lub usunąć.
                mergeDuplicates()
                Task { await ReminderScheduler.sync(context: modelContext) }
            }
            .onReceive(Self.accountChanges) { _ in
                Task { await cloudAccount.refresh() }
            }
    }

    /// Osobna flaga wgrania dla każdego magazynu; baza w pamięci nie ma flagi.
    private var seedStoreKey: String? {
        switch storeMode {
        case .cloudKit: "cloud"
        case .localOnly: "local"
        case .inMemory: nil
        }
    }

    private func seedSubjects() {
        do {
            let report = try SubjectSeeder.run(in: modelContext, storeKey: seedStoreKey)
            logger.info("Przedmioty: dodano \(report.inserted), scalono \(report.merged).")
        } catch {
            logger.error("Wgrywanie przedmiotów nie powiodło się: \(String(describing: error), privacy: .public)")
        }
    }

    /// Scalanie po synchronizacji: przedmioty i profile.
    private func mergeDuplicates() {
        mergeDuplicateSubjects()
        mergeDuplicateProfiles()
    }

    /// Profil („jeden na konto iCloud”) mógł powstać na dwóch urządzeniach przed synchronizacją.
    private func mergeDuplicateProfiles() {
        do {
            let repository = ProfileRepository(context: modelContext)
            let merged = try repository.mergeDuplicates()
            if modelContext.hasChanges {
                try modelContext.save()
            }
            if merged > 0 {
                logger.info("Scalono duplikaty profilu: \(merged).")
            }
        } catch {
            logger.error("Scalanie profili nie powiodło się: \(String(describing: error), privacy: .public)")
        }
    }

    private func mergeDuplicateSubjects() {
        do {
            let merged = try SubjectSeeder.mergeDuplicates(in: modelContext)
            if modelContext.hasChanges {
                try modelContext.save()
            }
            if merged > 0 {
                logger.info("Scalono duplikaty przedmiotów: \(merged).")
            }
        } catch {
            logger.error("Scalanie przedmiotów nie powiodło się: \(String(describing: error), privacy: .public)")
        }
    }
}
