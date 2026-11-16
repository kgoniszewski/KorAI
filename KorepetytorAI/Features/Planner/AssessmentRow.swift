import Core
import DesignSystem
import SwiftUI

extension AssessmentKind {
    /// Nazwa rodzaju dla użytkowniczki („Kartkówka”, „Sprawdzian”…).
    var title: LocalizedStringKey {
        switch self {
        case .shortQuiz: "assessment.kind.shortQuiz"
        case .test: "assessment.kind.test"
        case .classTest: "assessment.kind.classTest"
        case .other: "assessment.kind.other"
        }
    }

    /// Kolejność w edytorze: od najczęstszego.
    static let editorOrder: [AssessmentKind] = [.shortQuiz, .test, .classTest, .other]
}

extension AssessmentStatus {
    var title: LocalizedStringKey {
        switch self {
        case .upcoming: "assessment.status.upcoming"
        case .completed: "assessment.status.completed"
        case .cancelled: "assessment.status.cancelled"
        }
    }
}

/// Wygląd przedmiotu sprawdzianu; sprawdzian może nie mieć przedmiotu
/// (np. gdy relacja przyszła z iCloud później niż sam sprawdzian).
struct SubjectAppearance {
    let name: String
    let colorName: String
    let iconName: String

    init(_ subject: Subject?) {
        name = subject?.name ?? String(localized: "assessment.noSubject")
        colorName = subject?.colorName ?? SubjectPalette.slate.rawValue
        iconName = subject?.iconName ?? "questionmark.circle.fill"
    }

    var color: Color { SubjectPalette.color(named: colorName) }
}

/// Odliczanie do dnia sprawdzianu: „dziś”, „jutro”, „za 5 dni”, „wczoraj”, „3 dni temu”.
struct DayCountdownText: View {
    let date: Date
    var now: Date = .now

    var body: some View {
        let days = PlannerCalendar.daysBetween(now, and: date)
        switch days {
        case 0: Text("countdown.today")
        case 1: Text("countdown.tomorrow")
        case -1: Text("countdown.yesterday")
        case 2...: Text("countdown.inDays \(days)")
        default: Text("countdown.daysAgo \(-days)")
        }
    }
}

/// Wiersz sprawdzianu: ikona przedmiotu, rodzaj, przedmiot, zakres i stan lub odliczanie.
struct AssessmentRow: View {
    let assessment: Assessment
    /// Pokazuje datę pod nazwą (na ekranie Dziś; w Planerze data jest w nagłówku).
    var showsDate = false

    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 40

    var body: some View {
        let subject = SubjectAppearance(assessment.subject)
        HStack(alignment: .center, spacing: Spacing.m) {
            Image(systemName: subject.iconName)
                .font(Typography.headline)
                .foregroundStyle(subject.color)
                .frame(width: iconSize, height: iconSize)
                .background(subject.color.opacity(0.16), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(assessment.kind.title)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .strikethrough(assessment.status == .cancelled)
                Text(verbatim: subject.name)
                    .font(Typography.callout)
                    .foregroundStyle(Palette.textSecondary)
                if showsDate {
                    Text(assessment.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                if !assessment.scope.isEmpty {
                    Text(verbatim: assessment.scope)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: Spacing.s)

            trailing
                .font(Typography.caption)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var trailing: some View {
        switch assessment.status {
        case .upcoming:
            DayCountdownText(date: assessment.date)
                .foregroundStyle(Palette.accent)
        case .completed:
            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Label("assessment.status.completed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(SubjectPalette.emerald.color)
                if let grade = assessment.grade {
                    Text("assessment.gradeValue \(grade)")
                        .foregroundStyle(Palette.textPrimary)
                }
            }
        case .cancelled:
            Text("assessment.status.cancelled")
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
