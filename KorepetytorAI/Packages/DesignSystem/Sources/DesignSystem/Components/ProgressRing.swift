import SwiftUI

/// Pierścień postępu z opcjonalną zawartością w środku.
public struct ProgressRing<Center: View>: View {
    private let progress: Double
    private let lineWidth: CGFloat
    private let tint: Color
    private let center: Center

    public init(
        progress: Double,
        lineWidth: CGFloat = 12,
        tint: Color = Palette.accent,
        @ViewBuilder center: () -> Center
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.tint = tint
        self.center = center()
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: clampedProgress)
            center
        }
        .padding(lineWidth / 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(clampedProgress, format: .percent.precision(.fractionLength(0))))
    }
}

extension ProgressRing where Center == EmptyView {
    public init(progress: Double, lineWidth: CGFloat = 12, tint: Color = Palette.accent) {
        self.init(progress: progress, lineWidth: lineWidth, tint: tint) { EmptyView() }
    }
}

#Preview("Jasny") {
    HStack(spacing: Spacing.xl) {
        ProgressRing(progress: 0.65) {
            Text("65%")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(width: 96, height: 96)
        ProgressRing(progress: 0.3, tint: SubjectPalette.emerald.color)
            .frame(width: 96, height: 96)
    }
    .padding(Spacing.xl)
    .background(Palette.background)
}

#Preview("Ciemny, największy tekst") {
    ProgressRing(progress: 0.8) {
        Text("4/5")
            .font(Typography.headline)
            .foregroundStyle(Palette.textPrimary)
    }
    .frame(width: 140, height: 140)
    .padding(Spacing.xl)
    .background(Palette.background)
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility5)
}
