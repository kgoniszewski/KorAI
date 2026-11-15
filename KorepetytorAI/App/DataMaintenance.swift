import CloudKit
import Combine
import CoreData
import Core
import OSLog
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "KorepetytorAI", category: "DataMaintenance")

/// Utrzymanie danych w tle: wgranie przedmiotów, scalanie duplikatów po synchronizacji
/// i odświeżanie stanu konta iCloud.
struct DataMaintenance: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CloudAccountMonitor.self) private var cloudAccount

    func body(content: Content) -> some View {
        content
            .task {
                seedSubjects()
                await cloudAccount.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    mergeDuplicateSubjects()
                }
            }
            // Zmiany przychodzące z iCloud: po imporcie mogą pojawić się duplikaty
            // przedmiotów wgranych osobno na drugim urządzeniu.
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .NSPersistentStoreRemoteChange)
                    .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            ) { _ in
                mergeDuplicateSubjects()
            }
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .CKAccountChanged)
                    .receive(on: DispatchQueue.main)
            ) { _ in
                Task { await cloudAccount.refresh() }
            }
    }

    private func seedSubjects() {
        do {
            let report = try SubjectSeeder.run(in: modelContext)
            logger.info("Przedmioty: dodano \(report.inserted), scalono \(report.merged).")
        } catch {
            logger.error("Wgrywanie przedmiotów nie powiodło się: \(String(describing: error), privacy: .public)")
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
