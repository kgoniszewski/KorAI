import Core
import DesignSystem
import SwiftData
import SwiftUI
import UIKit

/// Profil (moduł „Nagrody i profil”). W M0: ekran zastępczy, stan iCloud
/// i lista przedmiotów z bazy do testu synchronizacji. Wejście do Strefy rodzica.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.storeMode) private var storeMode
    @Environment(CloudAccountMonitor.self) private var cloudAccount

    @Query(sort: [SortDescriptor(\Subject.sortOrder), SortDescriptor(\Subject.name)])
    private var subjects: [Subject]

    @State private var isShowingError = false
    @State private var errorText = ""

    var body: some View {
        List {
            Section {
                EmptyState(
                    "profile.empty.title",
                    message: "profile.empty.message",
                    systemImage: "star.circle.fill",
                    tint: SubjectPalette.magenta.color
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                LabeledContent("profile.sync.icloud") {
                    Text(cloudAccount.status.label)
                }
                LabeledContent("profile.sync.store") {
                    Text(storeMode.label)
                }
                if case .localOnly(.cloudKitUnavailable(let message)) = storeMode {
                    Text(verbatim: message)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Button("profile.sync.addTestSubject", systemImage: "plus.circle.fill", action: addTestSubject)
                Button("profile.sync.refresh", systemImage: "arrow.clockwise") {
                    Task { await cloudAccount.refresh() }
                }
            } header: {
                Text("profile.sync.header")
            } footer: {
                Text("profile.sync.footer")
            }

            Section {
                ForEach(subjects) { subject in
                    SubjectChip(name: subject.name, colorName: subject.colorName, iconName: subject.iconName)
                        .listRowBackground(Palette.surface)
                        .deleteDisabled(SubjectCatalog.containsDefault(named: subject.name))
                }
                .onDelete(perform: deleteSubjects)
            } header: {
                Text("profile.subjects.header \(subjects.count)")
            }

            Section {
                NavigationLink {
                    ParentZoneView()
                } label: {
                    Label("section.parentZone", systemImage: "lock.shield.fill")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("section.profile")
        .alert("common.error", isPresented: $isShowingError) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(verbatim: errorText)
        }
    }

    /// Dodaje przedmiot testowy z nazwą urządzenia i godziną, żeby na drugim
    /// urządzeniu było widać, skąd przyszedł.
    private func addTestSubject() {
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let time = Date.now.formatted(date: .omitted, time: .standard)
        let name = String(localized: "profile.sync.testSubjectName \(device) \(time)")
        do {
            try SubjectRepository(context: modelContext).addSubject(
                name: name,
                kind: .general,
                colorName: SubjectPalette.slate.rawValue,
                iconName: "arrow.triangle.2.circlepath"
            )
        } catch {
            show(error)
        }
    }

    /// Usuwa tylko przedmioty spoza listy startowej (w M0: przedmioty testowe).
    private func deleteSubjects(at offsets: IndexSet) {
        let repository = SubjectRepository(context: modelContext)
        do {
            for subject in offsets.map({ subjects[$0] })
            where !SubjectCatalog.containsDefault(named: subject.name) {
                try repository.delete(subject)
            }
        } catch {
            show(error)
        }
    }

    private func show(_ error: any Error) {
        errorText = error.localizedDescription
        isShowingError = true
    }
}

extension CloudAccountMonitor.Status {
    var label: LocalizedStringKey {
        switch self {
        case .checking: "icloud.status.checking"
        case .available: "icloud.status.available"
        case .noAccount: "icloud.status.noAccount"
        case .restricted: "icloud.status.restricted"
        case .temporarilyUnavailable: "icloud.status.temporarilyUnavailable"
        case .couldNotDetermine: "icloud.status.couldNotDetermine"
        case .notApplicable: "icloud.status.notApplicable"
        }
    }
}

extension StoreMode {
    var label: LocalizedStringKey {
        switch self {
        case .cloudKit: "profile.store.cloudKit"
        case .localOnly(.missingContainerIdentifier): "profile.store.localMissingID"
        case .localOnly(.cloudKitUnavailable): "profile.store.localError"
        case .inMemory: "profile.store.inMemory"
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(PreviewSupport.container)
    .environment(PreviewSupport.cloudAccount)
}
