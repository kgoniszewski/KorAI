import CloudKit
import Foundation
import Observation

/// Stan konta iCloud na urządzeniu, potrzebny na ekranie Profil w M0.
@MainActor
@Observable
public final class CloudAccountMonitor {
    public enum Status: Equatable, Sendable {
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case couldNotDetermine
        /// Aplikacja nie używa CloudKit w tym uruchomieniu (tryb lokalny lub w pamięci).
        case notApplicable
    }

    public private(set) var status: Status

    @ObservationIgnored
    private let containerIdentifier: String?

    /// - Parameter containerIdentifier: `nil`, gdy aplikacja działa bez CloudKit.
    ///   `CKContainer` powstaje tylko z identyfikatorem, bo bez uprawnień iCloud kończy działanie aplikacji.
    public init(containerIdentifier: String?) {
        self.containerIdentifier = containerIdentifier
        self.status = containerIdentifier == nil ? .notApplicable : .checking
    }

    public func refresh() async {
        guard let containerIdentifier else {
            status = .notApplicable
            return
        }
        do {
            let accountStatus = try await CKContainer(identifier: containerIdentifier).accountStatus()
            status = Status(accountStatus)
        } catch {
            status = .couldNotDetermine
        }
    }
}

extension CloudAccountMonitor.Status {
    init(_ accountStatus: CKAccountStatus) {
        switch accountStatus {
        case .available: self = .available
        case .noAccount: self = .noAccount
        case .restricted: self = .restricted
        case .temporarilyUnavailable: self = .temporarilyUnavailable
        case .couldNotDetermine: self = .couldNotDetermine
        @unknown default: self = .couldNotDetermine
        }
    }
}
