import DesignSystem
import SwiftUI

/// Siatka ośmiu awatarów do wyboru (wprowadzenie i edycja profilu).
struct AvatarPicker: View {
    @Binding var selection: AvatarID

    @ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 64

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: avatarSize + Spacing.l), spacing: Spacing.l)], spacing: Spacing.l) {
            ForEach(AvatarID.allCases) { avatar in
                let isSelected = avatar == selection
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        selection = avatar
                    }
                } label: {
                    AvatarView(avatar, size: avatarSize)
                        .padding(Spacing.xs)
                        .overlay {
                            Circle()
                                .strokeBorder(isSelected ? Palette.accent : .clear, lineWidth: 3)
                        }
                        .scaleEffect(isSelected ? 1.08 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(avatar.title))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

extension AvatarID {
    /// Nazwa awatara dla VoiceOver.
    var title: LocalizedStringKey {
        switch self {
        case .cat: "avatar.cat"
        case .dog: "avatar.dog"
        case .hare: "avatar.hare"
        case .bird: "avatar.bird"
        case .fish: "avatar.fish"
        case .tortoise: "avatar.tortoise"
        case .ladybug: "avatar.ladybug"
        case .lizard: "avatar.lizard"
        }
    }
}

#Preview {
    @Previewable @State var selection = AvatarID.cat
    AvatarPicker(selection: $selection)
        .padding()
}
