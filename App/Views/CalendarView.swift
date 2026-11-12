import SwiftUI
import TrayLogCore

struct CalendarView: View {
  @Environment(PlanStore.self) private var store

  @State private var visibleMonth = MonthGrid.month(containing: .now)

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        if let plan = store.plan {
          progressHeader(plan)
          monthCard(plan)
          upcomingCard(plan)
        } else {
          ContentUnavailableView(
            "No plan yet",
            systemImage: "calendar",
            description: Text("Create a plan on the Today tab to see your change days here.")
          )
        }
      }
      .padding()
    }
    .navigationTitle("Calendar")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func progressHeader(_ plan: TreatmentPlan) -> some View {
    let progress = plan.overallProgress(on: store.today)

    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(
          plan.isComplete
            ? "Treatment complete"
            : "Tray \(plan.currentTray) of \(plan.totalTrays)"
        )
        .font(.headline)
        Spacer()
        Text("\(Int((progress * 100).rounded()))%")
          .font(.headline)
          .foregroundStyle(Color.trayAccent)
      }
      ProgressView(value: progress)
        .tint(Color.trayAccent)
      if !plan.isComplete {
        Text("Day \(plan.dayNumberInTray(on: store.today)) of \(plan.daysPerTray)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func monthCard(_ plan: TreatmentPlan) -> some View {
    let calendar = Calendar.current
    let cells = MonthGrid.cells(for: visibleMonth, calendar: calendar)
    let changes = changeDays(plan, calendar: calendar)
    let currentPeriod = plan.trayPeriods(calendar: calendar)
      .first { $0.tray == plan.currentTray }

    return VStack(spacing: 12) {
      monthHeader(calendar)
      weekdayHeader(calendar)
      LazyVGrid(columns: columns, spacing: 4) {
        ForEach(cells.indices, id: \.self) { index in
          if let day = cells[index] {
            dayCell(
              day,
              plan: plan,
              change: changes[calendar.startOfDay(for: day)],
              inCurrentTray: isInCurrentTray(day, period: currentPeriod),
              calendar: calendar
            )
          } else {
            Color.clear.frame(height: 48)
          }
        }
      }
      legend
    }
    .padding(16)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private func monthHeader(_ calendar: Calendar) -> some View {
    let isCurrentMonth = calendar.isDate(
      visibleMonth,
      equalTo: store.today,
      toGranularity: .month
    )

    return HStack {
      Button {
        shiftMonth(-1)
      } label: {
        Image(systemName: "chevron.left")
          .frame(width: 32, height: 32)
      }
      Spacer()
      VStack(spacing: 2) {
        Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
          .font(.headline)
        if !isCurrentMonth {
          Button("Today") {
            visibleMonth = MonthGrid.month(containing: store.today)
          }
          .font(.caption)
        }
      }
      Spacer()
      Button {
        shiftMonth(1)
      } label: {
        Image(systemName: "chevron.right")
          .frame(width: 32, height: 32)
      }
    }
    .buttonStyle(.plain)
  }

  private func weekdayHeader(_ calendar: Calendar) -> some View {
    let symbols = MonthGrid.weekdaySymbols(calendar: calendar)

    return HStack(spacing: 4) {
      ForEach(symbols.indices, id: \.self) { index in
        Text(symbols[index])
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
      }
    }
  }

  private func dayCell(
    _ day: Date,
    plan: TreatmentPlan,
    change: TrayPeriod?,
    inCurrentTray: Bool,
    calendar: Calendar
  ) -> some View {
    let isToday = calendar.isDateInToday(day)
    let isPast = day < calendar.startOfDay(for: store.today)
    let label = change.map { changeLabel(for: $0, plan: plan) }

    return VStack(spacing: 2) {
      Text("\(calendar.component(.day, from: day))")
        .font(.callout.weight(isToday ? .bold : .regular))
        .foregroundStyle(isPast && change == nil ? .secondary : .primary)
      Text(label ?? " ")
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(isPast ? Color.secondary : Color.trayAccent)
        .opacity(change == nil ? 0 : 1)
    }
    .frame(maxWidth: .infinity, minHeight: 48)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(cellFill(change: change, inCurrentTray: inCurrentTray, isPast: isPast))
    )
    .overlay {
      if isToday {
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.trayAccent, lineWidth: 2)
      }
    }
  }

  private var legend: some View {
    HStack(spacing: 16) {
      legendItem(color: Color.trayAccent.opacity(0.9), text: "Change day")
      legendItem(color: Color.trayAccent.opacity(0.16), text: "Current tray")
      Spacer(minLength: 0)
    }
    .padding(.top, 4)
  }

  private func legendItem(color: Color, text: String) -> some View {
    HStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 3)
        .fill(color)
        .frame(width: 10, height: 10)
      Text(text)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private func upcomingCard(_ plan: TreatmentPlan) -> some View {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: store.today)
    let upcoming = plan.trayPeriods(calendar: calendar)
      .filter { $0.changeDate >= today }
      .prefix(5)

    return VStack(alignment: .leading, spacing: 10) {
      Text("Upcoming changes")
        .font(.headline)
      if upcoming.isEmpty {
        Text("No more change days left in this plan.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(upcoming)) { period in
          upcomingRow(period, plan: plan, today: today, calendar: calendar)
          if period.id != upcoming.last?.id {
            Divider()
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
  }

  private func upcomingRow(
    _ period: TrayPeriod,
    plan: TreatmentPlan,
    today: Date,
    calendar: Calendar
  ) -> some View {
    let days = calendar.dateComponents([.day], from: today, to: period.changeDate).day ?? 0
    let isLast = period.tray >= plan.totalTrays

    return HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(isLast ? "Finish treatment" : "Switch to tray \(period.tray + 1)")
          .font(.subheadline.weight(.medium))
        Text(
          period.changeDate.formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day()
          )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer()
      Text(CountdownLabel.compact(daysUntilChange: days))
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.trayAccent)
    }
  }

  private func changeDays(_ plan: TreatmentPlan, calendar: Calendar) -> [Date: TrayPeriod] {
    Dictionary(
      plan.trayPeriods(calendar: calendar).map {
        (calendar.startOfDay(for: $0.changeDate), $0)
      },
      uniquingKeysWith: { first, _ in first }
    )
  }

  private func isInCurrentTray(_ day: Date, period: TrayPeriod?) -> Bool {
    guard let period else { return false }
    return day >= period.startDate && day < period.changeDate
  }

  private func cellFill(change: TrayPeriod?, inCurrentTray: Bool, isPast: Bool) -> Color {
    if change != nil {
      return Color.trayAccent.opacity(isPast ? 0.10 : 0.18)
    }
    return inCurrentTray ? Color.trayAccent.opacity(0.06) : .clear
  }

  private func changeLabel(for period: TrayPeriod, plan: TreatmentPlan) -> String {
    period.tray >= plan.totalTrays ? "✓" : "T\(period.tray + 1)"
  }

  private func shiftMonth(_ offset: Int) {
    visibleMonth = MonthGrid.month(containing: visibleMonth, offset: offset)
  }
}
