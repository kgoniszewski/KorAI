import Core
import SwiftData
import SwiftUI

/// Wybiera między wprowadzeniem a główną nawigacją.
///
/// Profil jest czytany przez `@Query`, więc gdy w trakcie wprowadzenia przyjdzie z iCloud
/// profil utworzony na drugim urządzeniu, aplikacja sama przechodzi do ekranu Dziś.
/// Scalanie duplikatów (`ProfileRepository.mergeDuplicates`) robi `DataMaintenance`.
struct RootView: View {
    @Query private var profiles: [Profile]

    var body: some View {
        Group {
            if profiles.isEmpty {
                OnboardingView()
                    .transition(.opacity)
            } else {
                AppShell()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: profiles.isEmpty)
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewSupport.container)
        .environment(PreviewSupport.cloudAccount)
}
