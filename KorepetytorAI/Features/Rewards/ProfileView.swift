import Core
import DesignSystem
import SwiftData
import SwiftUI

/// Profil (moduł „Nagrody i profil”). W M1: pseudonim, awatar i stan iCloud;
/// wejście do Strefy rodzica. Punkty, monety i odznaki dochodzą w M3.
///
/// Profil nie powstaje tutaj: tworzy go tylko wprowadzenie.
struct ProfileView: View {
    @Environment(\.storeMode) private var storeMode
    @Environment(CloudAccountMonitor.self) private var cloudAccount

    @Query(sort: [SortDescriptor(\Profile.createdAt)])
    private var profiles: [Profile]

    @State private var isEditing = false

    var body: some View {
        List {
            if let profile = profiles.first {
                Section {
                    VStack(spacing: Spacing.m) {
                        AvatarView(avatarID: profile.avatarID, size: 96)
                        Text(verbatim: profile.nickname)
                            .font(Typography.display)
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.center)
                        Button("profile.edit", systemImage: "pencil") {
                            isEditing = true
                        }
                        .font(Typography.callout.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.l)
                    .listRowBackground(Color.clear)
                }
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
                Button("profile.sync.refresh", systemImage: "arrow.clockwise") {
                    Task { await cloudAccount.refresh() }
                }
            } header: {
                Text("profile.sync.header")
            } footer: {
                Text("profile.sync.footer")
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
        .sheet(isPresented: $isEditing) {
            if let profile = profiles.first {
                ProfileEditorView(profile: profile)
            }
        }
    }
}

/// Zmiana pseudonimu i awatara.
struct ProfileEditorView: View {
    let profile: Profile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String
    @State private var avatar: AvatarID
    @State private var errorText: String?

    init(profile: Profile) {
        self.profile = profile
        _nickname = State(initialValue: profile.nickname)
        _avatar = State(initialValue: AvatarID.resolve(profile.avatarID))
    }

    private var canSave: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("profile.editor.nickname") {
                    TextField("onboarding.nickname.placeholder", text: $nickname)
                        .textContentType(.nickname)
                        .textInputAutocapitalization(.words)
                        .onChange(of: nickname) { _, newValue in
                            if newValue.count > ProfileRepository.maxNicknameLength {
                                nickname = String(newValue.prefix(ProfileRepository.maxNicknameLength))
                            }
                        }
                }
                Section("profile.editor.avatar") {
                    AvatarPicker(selection: $avatar)
                        .padding(.vertical, Spacing.s)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("profile.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(!canSave)
                }
            }
            .alert("common.error", isPresented: $errorText.isPresent()) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(verbatim: errorText ?? "")
            }
        }
    }

    private func save() {
        do {
            try ProfileRepository(context: modelContext).update(profile, nickname: nickname, avatarID: avatar.rawValue)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
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
