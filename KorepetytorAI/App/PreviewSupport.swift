import Core
import SwiftData

/// Wspólne dane dla podglądów SwiftUI w aplikacji.
@MainActor
enum PreviewSupport {
    static let container: ModelContainer = PreviewData.makeContainer()
    static let cloudAccount = CloudAccountMonitor(containerIdentifier: nil)
}
