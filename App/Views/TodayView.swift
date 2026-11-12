import SwiftUI
import TrayLogCore

struct TodayView: View {
  @Environment(PlanStore.self) private var store

  @State private var isEditingPlan = false
  @State private var isStartingNewPlan = false
  @State private var isConfirmingChange = false

  var body: some View {
    if let plan = store.plan {
      content(plan: plan)
        .sheet(isPresented: $isEditingPlan) {
          PlanFormView(mode: .edit, plan: plan)
            .environment(store)
        }
        .sheet(isPresented: $isStartingNewPlan) {
          PlanFormView(mode: .create, plan: nil)
            .environment(store)
        }
        .confirmationDialog(
          "Change tray?",
          isPresented: $isConfirmingChange,
          titleVisibility: .visible
        ) {
          Button(changeButtonTitle(plan: plan)) {
            store.advanceTray()
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text(
            "The next tray's wear period starts today, and the rest of the schedule "
              + "moves with it."
          )
        }
    }
  }

  @ViewBuilder
  private func content(plan: TreatmentPlan) -> some View {
    let now = store.today
    let calendar = Calendar.current
    let progress = plan.overallProgress(on: now, calendar: calendar)
    let daysUntilChange = plan.daysUntilChange(on: now, calendar: calendar)

    ScrollView {
      VStack(spacing: 24) {
        ProgressRing(progress: progress) {
          ringLabel(plan: plan, progress: progress)
        }
        .frame(width: 220, height: 220)
        .padding(.top, 12)

        statusCard(plan: plan, now: now, daysUntilChange: daysUntilChange)

        actionButton(plan: plan)

        Text(
          "TrayLog is a schedule tracker, not medical advice. Follow your orthodontist's "
            + "plan and check tray fit before switching."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      }
      .padding(.horizontal)
      .padding(.bottom, 32)
    }
    .toolbar {
      Button {
        isEditingPlan = true
      } label: {
        Label("Edit plan", systemImage: "slider.horizontal.3")
      }
    }
  }

  @ViewBuilder
  private func ringLabel(plan: TreatmentPlan, progress: Double) -> some View {
    VStack(spacing: 4) {
      Text(plan.isComplete ? "Done" : "Tray \(plan.currentTray)")
        .font(.system(size: 40, weight: .bold, design: .rounded))
        .contentTransition(.numericText())
      Text("of \(plan.totalTrays)")
        .font(.headline)
        .foregroundStyle(.secondary)
      Text("\(Int((progress * 100).rounded()))%")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.trayAccent)
        .padding(.top, 2)
    }
  }

  @ViewBuilder
  private func statusCard(plan: TreatmentPlan, now: Date, daysUntilChange: Int) -> some View {
    VStack(spacing: 0) {
      if plan.isComplete {
        row(title: "Treatment", value: "All \(plan.totalTrays) trays complete")
        divider
        row(title: "Finished", value: completedText(plan: plan))
      } else {
        row(
          title: "Current tray",
          value: "Day \(plan.dayNumberInTray(on: now)) of \(plan.daysPerTray)"
        )
        divider
        row(title: "Change day", value: changeDateText(plan: plan))
        divider
        row(
          title: "Status",
          value: CountdownLabel.changeStatus(daysUntilChange: daysUntilChange)
        )
        divider
        row(title: "Projected finish", value: projectedText(plan: plan))
      }
    }
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }

  private var divider: some View {
    Divider().padding(.leading, 16)
  }

  private func row(title: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title)
        .foregroundStyle(.secondary)
      Spacer(minLength: 16)
      Text(value)
        .multilineTextAlignment(.trailing)
    }
    .font(.subheadline)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  @ViewBuilder
  private func actionButton(plan: TreatmentPlan) -> some View {
    if plan.isComplete {
      Button {
        isStartingNewPlan = true
      } label: {
        Label("Start a new plan", systemImage: "plus.circle.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    } else {
      Button {
        isConfirmingChange = true
      } label: {
        Label(changeButtonTitle(plan: plan), systemImage: "arrow.right.circle.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
  }

  private func changeButtonTitle(plan: TreatmentPlan) -> String {
    plan.currentTray >= plan.totalTrays
      ? "Finish final tray"
      : "Change to tray \(plan.currentTray + 1)"
  }

  private func changeDateText(plan: TreatmentPlan) -> String {
    plan.changeDate().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
  }

  private func projectedText(plan: TreatmentPlan) -> String {
    plan.projectedEndDate().formatted(date: .abbreviated, time: .omitted)
  }

  private func completedText(plan: TreatmentPlan) -> String {
    guard let completedOn = plan.completedOn else { return "Today" }
    return completedOn.formatted(date: .abbreviated, time: .omitted)
  }
}
