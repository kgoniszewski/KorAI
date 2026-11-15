import CoreData
import Foundation
import OSLog
import SwiftData

/// Sposób przechowywania danych w bieżącym uruchomieniu.
public enum StoreMode: Equatable, Sendable {
    /// Synchronizacja przez prywatną bazę iCloud.
    case cloudKit(containerIdentifier: String)
    /// Baza tylko na urządzeniu (bez synchronizacji), z podanego powodu.
    case localOnly(LocalOnlyReason)
    /// Baza w pamięci: testy, podglądy SwiftUI, awaryjny tryb.
    case inMemory

    public var cloudKitContainerIdentifier: String? {
        if case .cloudKit(let identifier) = self { identifier } else { nil }
    }
}

/// Powód pracy bez synchronizacji.
public enum LocalOnlyReason: Equatable, Sendable {
    /// W Info.plist brakuje identyfikatora kontenera CloudKit.
    case missingContainerIdentifier
    /// Utworzenie bazy z CloudKit się nie powiodło.
    case cloudKitUnavailable(message: String)
}

/// Kontener SwiftData razem z trybem, w jakim powstał.
public struct PersistenceSetup: Sendable {
    public let container: ModelContainer
    public let mode: StoreMode

    public init(container: ModelContainer, mode: StoreMode) {
        self.container = container
        self.mode = mode
    }
}

public enum PersistenceError: Error, Sendable {
    case cannotBuildManagedObjectModel
}

/// Fabryka kontenerów SwiftData.
public enum Persistence {
    /// Nazwa magazynu synchronizowanego z iCloud.
    public static let cloudKitStoreName = "KorepetytorAI"
    /// Nazwa awaryjnego magazynu lokalnego (osobny plik, nigdy nie trafia do iCloud).
    public static let localStoreName = "KorepetytorAI-local"

    private static let logger = Logger(subsystem: "KorepetytorAI", category: "Persistence")

    public static func makeSchema() -> Schema {
        Schema(versionedSchema: SchemaV1.self)
    }

    /// Kontener w pamięci, bez CloudKit: testy i podglądy.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = makeSchema()
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: KorepetytorMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Konfiguracja magazynu synchronizowanego z prywatną bazą CloudKit.
    public static func cloudKitConfiguration(containerIdentifier: String, schema: Schema) -> ModelConfiguration {
        ModelConfiguration(
            cloudKitStoreName,
            schema: schema,
            cloudKitDatabase: .private(containerIdentifier)
        )
    }

    /// Kontener synchronizowany z prywatną bazą iCloud.
    public static func makeCloudKitContainer(containerIdentifier: String) throws -> ModelContainer {
        let schema = makeSchema()
        try ensureApplicationSupportDirectory()
        return try ModelContainer(
            for: schema,
            migrationPlan: KorepetytorMigrationPlan.self,
            configurations: [cloudKitConfiguration(containerIdentifier: containerIdentifier, schema: schema)]
        )
    }

    /// Kontener lokalny, bez synchronizacji.
    public static func makeLocalContainer() throws -> ModelContainer {
        let schema = makeSchema()
        let directory = try ensureApplicationSupportDirectory()
        let configuration = ModelConfiguration(
            localStoreName,
            schema: schema,
            url: directory.appending(path: "\(localStoreName).store"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: KorepetytorMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Czy identyfikator wygląda na prawdziwy kontener (`iCloud.<identyfikator>`),
    /// a nie na nierozwinięte ustawienie kompilacji.
    public static func isValidContainerIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("iCloud.")
            && identifier.count > "iCloud.".count
            && !identifier.contains("$(")
            && !identifier.contains(" ")
    }

    /// Kontener aplikacji. Nigdy nie kończy działania aplikacji:
    /// gdy CloudKit zawiedzie, przechodzi w tryb lokalny, a tryb widać na ekranie Profil.
    ///
    /// - Parameters:
    ///   - containerIdentifier: identyfikator kontenera CloudKit z Info.plist.
    ///   - inMemory: wymusza bazę w pamięci (testy, podglądy).
    ///   - initializeSchema: tylko w wersji Debug; wysyła pełny schemat do środowiska
    ///     Development w CloudKit (argument uruchomienia `-initializeCloudKitSchema`).
    public static func makeAppSetup(
        containerIdentifier: String?,
        inMemory: Bool,
        initializeSchema: Bool
    ) -> PersistenceSetup {
        if inMemory {
            return inMemorySetup()
        }

        let identifier = containerIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard isValidContainerIdentifier(identifier) else {
            logger.error("Brak poprawnego identyfikatora kontenera CloudKit; baza tylko lokalna.")
            return localSetup(reason: .missingContainerIdentifier)
        }

        #if DEBUG
        if initializeSchema {
            do {
                try initializeCloudKitSchema(containerIdentifier: identifier)
                logger.notice("Schemat CloudKit wysłany do środowiska Development.")
            } catch {
                logger.error("Inicjalizacja schematu CloudKit nie powiodła się: \(String(describing: error), privacy: .public)")
            }
        }
        #endif

        do {
            let container = try makeCloudKitContainer(containerIdentifier: identifier)
            return PersistenceSetup(container: container, mode: .cloudKit(containerIdentifier: identifier))
        } catch {
            logger.error("Nie udało się utworzyć bazy z CloudKit: \(String(describing: error), privacy: .public)")
            return localSetup(reason: .cloudKitUnavailable(message: String(describing: error)))
        }
    }

    /// Wysyła pełny schemat (wszystkie typy rekordów) do środowiska Development w CloudKit.
    ///
    /// SwiftData tworzy typy rekordów dopiero przy pierwszym zapisie danego typu,
    /// więc bez tego kroku CloudKit Console pokazuje tylko część encji.
    /// Wzorzec za dokumentacją Apple „Syncing model data across a person's devices”.
    public static func initializeCloudKitSchema(containerIdentifier: String) throws {
        let configuration = cloudKitConfiguration(containerIdentifier: containerIdentifier, schema: makeSchema())
        try ensureApplicationSupportDirectory()
        try autoreleasepool {
            let description = NSPersistentStoreDescription(url: configuration.url)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: containerIdentifier
            )
            description.shouldAddStoreAsynchronously = false

            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models) else {
                throw PersistenceError.cannotBuildManagedObjectModel
            }
            let container = NSPersistentCloudKitContainer(name: cloudKitStoreName, managedObjectModel: model)
            container.persistentStoreDescriptions = [description]

            let loadResult = LoadErrorBox()
            container.loadPersistentStores { _, error in
                loadResult.error = error
            }
            if let error = loadResult.error {
                throw error
            }

            try container.initializeCloudKitSchema()

            for store in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    }

    // MARK: - Prywatne

    private static func inMemorySetup() -> PersistenceSetup {
        do {
            return PersistenceSetup(container: try makeInMemoryContainer(), mode: .inMemory)
        } catch {
            fatalError("Nie można utworzyć bazy w pamięci: \(error)")
        }
    }

    private static func localSetup(reason: LocalOnlyReason) -> PersistenceSetup {
        do {
            return PersistenceSetup(container: try makeLocalContainer(), mode: .localOnly(reason))
        } catch {
            logger.error("Nie udało się otworzyć bazy lokalnej: \(String(describing: error), privacy: .public)")
            return inMemorySetup()
        }
    }

    @discardableResult
    private static func ensureApplicationSupportDirectory() throws -> URL {
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

/// Przenosi błąd z wywołania zwrotnego `loadPersistentStores`
/// (przy `shouldAddStoreAsynchronously = false` wywoływanego synchronicznie).
private final class LoadErrorBox: @unchecked Sendable {
    var error: (any Error)?
}
