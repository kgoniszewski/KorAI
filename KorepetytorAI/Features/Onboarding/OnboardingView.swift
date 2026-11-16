import Core
import DesignSystem
import SwiftData
import SwiftUI

/// Wprowadzenie przy pierwszym uruchomieniu: pseudonim, awatar, gotowe.
/// Pokazuje się pełnoekranowo, dopóki w bazie nie ma profilu (`RootView`).
struct OnboardingView: View {
    private enum Step: Int, Comparable {
        case nickname
        case avatar
        case done

        static func < (lhs: Step, rhs: Step) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    @Environment(\.modelContext) private var modelContext

    @State private var step: Step = .nickname
    @State private var nickname = ""
    @State private var avatar: AvatarID = .fallback
    @State private var errorText: String?
    @FocusState private var isNicknameFocused: Bool

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    progress
                    switch step {
                    case .nickname: nicknameStep
                    case .avatar: avatarStep
                    case .done: doneStep
                    }
                }
                .padding(Spacing.xl)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            buttons
                .padding(Spacing.l)
                .frame(maxWidth: 560)
        }
        .background(Palette.background.ignoresSafeArea())
        .animation(.spring(duration: 0.35), value: step)
        .alert("common.error", isPresented: $errorText.isPresent()) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(verbatim: errorText ?? "")
        }
    }

    // MARK: - Kroki

    private var progress: some View {
        HStack(spacing: Spacing.s) {
            ForEach([Step.nickname, .avatar, .done], id: \.self) { item in
                Capsule()
                    .fill(item <= step ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Palette.textSecondary.opacity(0.25)))
                    .frame(height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("onboarding.progress \(step.rawValue + 1) \(3)"))
    }

    private var nicknameStep: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("onboarding.nickname.title")
                .font(Typography.display)
                .foregroundStyle(Palette.textPrimary)
            Text("onboarding.nickname.message")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
            TextField("onboarding.nickname.placeholder", text: $nickname)
                .font(Typography.title)
                .textContentType(.nickname)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($isNicknameFocused)
                .onSubmit(goForward)
                .padding(Spacing.l)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .onChange(of: nickname) { _, newValue in
                    if newValue.count > ProfileRepository.maxNicknameLength {
                        nickname = String(newValue.prefix(ProfileRepository.maxNicknameLength))
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { isNicknameFocused = true }
    }

    private var avatarStep: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("onboarding.avatar.title \(trimmedNickname)")
                .font(Typography.display)
                .foregroundStyle(Palette.textPrimary)
            Text("onboarding.avatar.message")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
            AvatarPicker(selection: $avatar)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var doneStep: some View {
        VStack(spacing: Spacing.l) {
            AvatarView(avatar, size: 120)
            Text(verbatim: trimmedNickname)
                .font(Typography.display)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("onboarding.done.message")
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xl)
    }

    // MARK: - Przyciski

    private var buttons: some View {
        HStack(spacing: Spacing.m) {
            if step != .nickname {
                Button("onboarding.back", action: goBack)
                    .font(Typography.headline)
                    .padding(.horizontal, Spacing.l)
            }
            switch step {
            case .nickname, .avatar:
                PrimaryButton("onboarding.next", action: goForward)
                    .disabled(trimmedNickname.isEmpty)
            case .done:
                PrimaryButton("onboarding.done", systemImage: "checkmark", action: finish)
            }
        }
    }

    private func goForward() {
        guard !trimmedNickname.isEmpty else { return }
        isNicknameFocused = false
        switch step {
        case .nickname: step = .avatar
        case .avatar: step = .done
        case .done: finish()
        }
    }

    private func goBack() {
        switch step {
        case .nickname: break
        case .avatar: step = .nickname
        case .done: step = .avatar
        }
    }

    /// Tworzy profil tylko wtedy, gdy nadal go nie ma: w trakcie wprowadzenia
    /// mógł przyjść z iCloud z drugiego urządzenia. `RootView` przełącza się wtedy sam.
    private func finish() {
        let repository = ProfileRepository(context: modelContext)
        do {
            if try repository.currentProfile() == nil {
                try repository.createProfile(nickname: trimmedNickname, avatarID: avatar.rawValue)
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(PreviewSupport.container)
}
