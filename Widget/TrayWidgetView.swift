import SwiftUI
import TrayLogCore
import WidgetKit

struct TrayWidgetView: View {
  @Environment(\.widgetFamily) private var family

  let entry: TrayEntry

  var body: some View {
    Group {
      if let plan = entry.plan {
        content(for: plan)
      } else {
        emptyState
      }
    }
    .containerBackground(for: .widget) {
      background
    }
  }

  @ViewBuilder
  private func content(for plan: TreatmentPlan) -> some View {
    switch family {
    case .accessoryCircular:
      circular(plan)
    case .accessoryRectangular:
      rectangular(plan)
    case .systemMedium:
      medium(plan)
    default:
      small(plan)
    }
  }

  private func small(_ plan: TreatmentPlan) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline) {
        Text("TRAY \(plan.currentTray)")
          .font(.caption2.weight(.bold))
          .foregroundStyle(Color.trayAccent)
        Spacer(minLength: 0)
        Text(percentText(plan))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Text("Day \(plan.dayNumberInTray(on: entry.date)) of \(plan.daysPerTray)")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
      Text(CountdownLabel.changeStatus(daysUntilChange: daysUntilChange(plan)))
        .font(.system(.headline, design: .rounded).weight(.semibold))
        .lineLimit(2)
        .minimumScaleFactor(0.7)
      ProgressView(value: progress(plan))
        .tint(Color.trayAccent)
    }
  }

  private func medium(_ plan: TreatmentPlan) -> some View {
    HStack(spacing: 18) {
      ring(plan)
      VStack(alignment: .leading, spacing: 4) {
        Text("Tray \(plan.currentTray) of \(plan.totalTrays)")
          .font(.headline)
        Text(
          "Day \(plan.dayNumberInTray(on: entry.date)) of \(plan.daysPerTray) · "
            + percentText(plan)
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        Text(CountdownLabel.changeStatus(daysUntilChange: daysUntilChange(plan)))
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.trayAccent)
        Text("Change \(changeDateText(plan))")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
  }

  private func ring(_ plan: TreatmentPlan) -> some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.18), lineWidth: 9)
      Circle()
        .trim(from: 0, to: min(max(progress(plan), 0), 1))
        .stroke(Color.trayAccent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
        .rotationEffect(.degrees(-90))
      VStack(spacing: 0) {
        Text("\(plan.currentTray)")
          .font(.system(size: 30, weight: .bold, design: .rounded))
        Text("of \(plan.totalTrays)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: 86, height: 86)
  }

  private func circular(_ plan: TreatmentPlan) -> some View {
    Gauge(value: progress(plan)) {
      Text("Tray")
    } currentValueLabel: {
      Text("\(plan.currentTray)")
        .font(.system(.body, design: .rounded).weight(.semibold))
    }
    .gaugeStyle(.accessoryCircularCapacity)
  }

  private func rectangular(_ plan: TreatmentPlan) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("Tray \(plan.currentTray) of \(plan.totalTrays)")
        .font(.headline)
      Text("Day \(plan.dayNumberInTray(on: entry.date)) of \(plan.daysPerTray)")
        .font(.caption)
      Text(CountdownLabel.compact(daysUntilChange: daysUntilChange(plan)))
        .font(.caption.weight(.semibold))
    }
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("TrayLog")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.trayAccent)
      Text("Open the app to set up your tray plan.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var background: some View {
    if family == .systemSmall || family == .systemMedium {
      LinearGradient(
        colors: [Color.trayAccent.opacity(0.16), Color.trayAccent.opacity(0.03)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    } else {
      Color.clear
    }
  }

  private func progress(_ plan: TreatmentPlan) -> Double {
    plan.overallProgress(on: entry.date)
  }

  private func daysUntilChange(_ plan: TreatmentPlan) -> Int {
    plan.daysUntilChange(on: entry.date)
  }

  private func percentText(_ plan: TreatmentPlan) -> String {
    "\(Int((progress(plan) * 100).rounded()))%"
  }

  private func changeDateText(_ plan: TreatmentPlan) -> String {
    plan.changeDate().formatted(.dateTime.month(.abbreviated).day())
  }
}
