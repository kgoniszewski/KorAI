import Core
import SwiftData
import SwiftUI

@main
struct KorepetytorAIApp: App {
    private let persistence: PersistenceSetup
    @State private var cloudAccount: CloudAccountMonitor

    init() {
        let options = LaunchOptions.current
        let setup = Persistence.makeAppSetup(
            containerIdentifier: options.cloudKitContainerIdentifier,
            inMemory: options.useInMemoryStore,
            initializeSchema: options.initializeCloudKitSchema
        )
        persistence = setup
        _cloudAccount = State(initialValue: CloudAccountMonitor(
            containerIdentifier: setup.mode.cloudKitContainerIdentifier
        ))
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .modifier(DataMaintenance())
                .environment(cloudAccount)
                .environment(\.storeMode, persistence.mode)
        }
        .modelContainer(persistence.container)
    }
}

/// Ustawienia uruchomienia odczytane z Info.plist i argumentów procesu.
struct LaunchOptions {
    /// Wartość `KorCloudKitContainerIdentifier` z Info.plist (`iCloud.<identyfikator>`).
    let cloudKitContainerIdentifier: String?
    /// Baza w pamięci: argument `-inMemoryStore`, testy i podglądy Xcode.
    let useInMemoryStore: Bool
    /// Argument `-initializeCloudKitSchema` (tylko Debug): wysyła schemat do CloudKit.
    let initializeCloudKitSchema: Bool

    static var current: LaunchOptions {
        let process = ProcessInfo.processInfo
        let isTesting = process.environment["XCTestConfigurationFilePath"] != nil
        let isPreview = process.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        return LaunchOptions(
            cloudKitContainerIdentifier: Bundle.main.object(forInfoDictionaryKey: "KorCloudKitContainerIdentifier") as? String,
            useInMemoryStore: process.arguments.contains("-inMemoryStore") || isTesting || isPreview,
            initializeCloudKitSchema: process.arguments.contains("-initializeCloudKitSchema")
        )
    }
}

extension EnvironmentValues {
    /// Tryb bazy danych bieżącego uruchomienia (pokazywany na ekranie Profil).
    @Entry var storeMode: StoreMode = .inMemory
}
