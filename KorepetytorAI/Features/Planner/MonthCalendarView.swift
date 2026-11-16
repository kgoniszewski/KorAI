import Core
import DesignSystem
import SwiftUI

/// Widok miesiąca: siatka od poniedziałku z kropkami w kolorach przedmiotów,
/// a pod nią terminy wybranego dnia.
struct MonthCalendarView: View {
    let assessments: [Assessment]
    @Binding var month: Date
    @Binding var selectedDay: Date
    let onSelect: (Assessment) -> Void
    let onComplete: (Assessment) -> Void
    let onDelete: (Assessment) -> Void
    let onAdd: (Date) -> Void

    private let calendar = PlannerCalendar.mondayFirst()

    var body: some View {
        let byDay = Dictionary(grouping: assessments) { calendar.startOfDay(for: $0.date) }
        let dayItems = byDay[calendar.startOfDay(for: selectedDay)] ?? []

        List {
            Section {
                VStack(spacing: Spacing.m) {
                    header
                    MonthGridView(
                        grid: PlannerCalendar.monthGrid(for: month, calendar: calendar),
                        assessmentsByDay: byDay,
                        selectedDay: $selectedDay,
                        calendar: calendar
                    )
                }
                .padding(.vertical, Spacing.s)
                .listRowBackground(Palette.surface)
            }

            Section {
                if dayItems.isEmpty {
                    Text("planner.month.noAssessments")
                        .font(Typography.callout)
                        .foregroundStyle(Palette.textSecondary)
                        .listRowBackground(Palette.surface)
                } else {
                    ForEach(dayItems) { assessment in
                        AssessmentListRow(
                            assessment: assessment,
                            onSelect: onSelect,
                            onComplete: onComplete,
                            onDelete: onDelete
                        )
                    }
                }
                Button("planner.month.addOnDay", systemImage: "plus.circle.fill") {
                    onAdd(selectedDay)
                }
                .listRowBackground(Palette.surface)
            } header: {
                Text(selectedDay, format: .dateTime.weekday(.wide).day().month(.wide))
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var header: some View {
        HStack(spacing: Spacing.s) {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("planner.month.previous"))

            Text(month, format: .dateTime.month(.wide).year())
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("planner.month.next"))

            Button("planner.month.today") {
                let today = calendar.startOfDay(for: .now)
                withAnimation {
                    month = PlannerCalendar.startOfMonth(for: today, calendar: calendar)
                    selectedDay = today
                }
            }
            .font(Typography.callout.weight(.semibold))
        }
        .buttonStyle(.borderless)
    }

    private func changeMonth(by value: Int) {
        withAnimation {
            month = PlannerCalendar.month(byAdding: value, to: month, calendar: calendar)
            // Zaznaczenie przechodzi na ten sam dzień miesiąca (albo ostatni dzień krótszego miesiąca).
            let day = calendar.component(.day, from: selectedDay)
            let grid = PlannerCalendar.monthGrid(for: month, calendar: calendar)
            if let target = grid.days[safe: min(day, grid.days.count) - 1] {
                selectedDay = target
            }
        }
    }
}

/// Siatka dni miesiąca.
private struct MonthGridView: View {
    let grid: MonthGrid
    let assessmentsByDay: [Date: [Assessment]]
    @Binding var selectedDay: Date
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.xs) {
            ForEach(Array(PlannerCalendar.weekdaySymbolsMondayFirst(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                Text(verbatim: symbol)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityHidden(true)
            }
            ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
                Color.clear
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
            ForEach(grid.days, id: \.self) { day in
                DayCell(
                    day: day,
                    assessments: assessmentsByDay[day] ?? [],
                    isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                    isToday: calendar.isDateInToday(day),
                    calendar: calendar
                ) {
                    selectedDay = day
                }
            }
        }
    }
}

/// Pole dnia: numer i do trzech kropek w kolorach przedmiotów, reszta jako „+N”.
private struct DayCell: View {
    static let maxDots = 3

    let day: Date
    let assessments: [Assessment]
    let isSelected: Bool
    let isToday: Bool
    let calendar: Calendar
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var cellHeight: CGFloat = 48
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 6

    var body: some View {
        let visible = assessments.prefix(Self.maxDots)
        let overflow = assessments.count - visible.count

        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Text(verbatim: "\(calendar.component(.day, from: day))")
                    .font(Typography.callout.weight(isToday || isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? Palette.accentForeground : (isToday ? Palette.accent : Palette.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 2) {
                    ForEach(Array(visible)) { assessment in
                        Circle()
                            .fill(SubjectAppearance(assessment.subject).color)
                            .frame(width: dotSize, height: dotSize)
                    }
                    if overflow > 0 {
                        Text(verbatim: "+\(overflow)")
                            .font(.system(size: dotSize * 1.6, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Palette.accentForeground : Palette.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .frame(height: dotSize * 1.8)
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .background {
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Color.clear))
            }
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(Palette.accent, lineWidth: 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(Text("planner.month.dayCount \(assessments.count)"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

extension Array {
    /// Element pod indeksem albo `nil` poza zakresem.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
