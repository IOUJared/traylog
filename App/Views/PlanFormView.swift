import SwiftUI
import TrayLogCore
import UIKit

struct PlanFormView: View {
  enum Mode {
    case create
    case edit
  }

  private enum DateAnchor: Hashable {
    case treatmentStart
    case currentTrayStart
  }

  @Environment(PlanStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  private let mode: Mode

  @State private var totalTrays: Int
  @State private var daysPerTray: Int
  @State private var currentTray: Int
  @State private var dateAnchor: DateAnchor
  @State private var trayStartDate: Date
  @State private var treatmentStartDate: Date
  @State private var reminderEnabled: Bool
  @State private var reminderTime: Date
  @State private var errorMessage: String?
  @State private var isConfirmingDelete = false
  @State private var isSaving = false
  @State private var showsPermissionAlert = false

  init(mode: Mode, plan: TreatmentPlan?) {
    self.mode = mode
    let calendar = Calendar.current

    _totalTrays = State(initialValue: plan?.totalTrays ?? 20)
    _daysPerTray = State(initialValue: plan?.daysPerTray ?? 14)
    _currentTray = State(initialValue: plan?.currentTray ?? 1)

    let trayStart = plan?.trayStartDate ?? calendar.startOfDay(for: .now)
    _trayStartDate = State(initialValue: trayStart)
    _treatmentStartDate = State(initialValue: plan?.treatmentStartDate() ?? trayStart)
    _dateAnchor = State(initialValue: mode == .create ? .treatmentStart : .currentTrayStart)

    _reminderEnabled = State(initialValue: plan?.notificationsEnabled ?? true)

    let base = calendar.startOfDay(for: .now)
    let time = calendar.date(
      bySettingHour: plan?.reminderHour ?? 20,
      minute: plan?.reminderMinute ?? 0,
      second: 0,
      of: base
    ) ?? base
    _reminderTime = State(initialValue: time)
  }

  var body: some View {
    NavigationStack {
      Form {
        planSection
        reminderSection
        if let errorMessage {
          Section {
            Text(errorMessage)
              .foregroundStyle(.red)
          }
        }
        if mode == .edit {
          deleteSection
        }
      }
      .navigationTitle(mode == .create ? "New plan" : "Plan")
      .navigationBarTitleDisplayMode(.inline)
      .scrollDismissesKeyboard(.interactively)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            save()
          }
          .disabled(isSaving)
        }
      }
      .confirmationDialog(
        "Delete this plan?",
        isPresented: $isConfirmingDelete,
        titleVisibility: .visible
      ) {
        Button("Delete plan", role: .destructive) {
          store.clear()
          dismiss()
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Your tray history and reminder are removed. This cannot be undone.")
      }
      .alert("Notifications are off", isPresented: $showsPermissionAlert) {
        Button("Open Settings") {
          openSettings()
        }
        Button("OK") {
          dismiss()
        }
      } message: {
        Text(
          "TrayLog saved your plan, but it cannot send the change-day reminder "
            + "until notifications are allowed."
        )
      }
    }
  }

  private var planSection: some View {
    Section {
      CountFieldRow(title: "Total trays", value: $totalTrays, range: 1...300)
      CountFieldRow(title: "Days per tray", value: $daysPerTray, range: 1...60)
      CountFieldRow(title: "Current tray", value: $currentTray, range: 1...totalTrays)
      Picker("Calculate from", selection: $dateAnchor) {
        Text("Treatment start").tag(DateAnchor.treatmentStart)
        Text("Current tray start").tag(DateAnchor.currentTrayStart)
      }
      .pickerStyle(.segmented)

      if dateAnchor == .treatmentStart {
        DatePicker(
          "Treatment started",
          selection: $treatmentStartDate,
          displayedComponents: .date
        )
      } else {
        DatePicker("Current tray started", selection: $trayStartDate, displayedComponents: .date)
      }
    } header: {
      Text("Treatment")
    } footer: {
      scheduleFooter
    }
    .onChange(of: totalTrays) { _, newValue in
      if currentTray > newValue {
        currentTray = newValue
      }
    }
    .onChange(of: dateAnchor) { _, newValue in
      syncDates(to: newValue)
    }
  }

  @ViewBuilder
  private var scheduleFooter: some View {
    if dateAnchor == .treatmentStart, let derived = derivedTrayStartDate {
      if derived > Calendar.current.startOfDay(for: .now) {
        Text(
          "Tray \(currentTray) starts \(shortDate(derived)) — in the future. "
            + "Check the treatment start and tray number."
        )
        .foregroundStyle(.orange)
      } else {
        Text(
          "Tray \(currentTray) starts \(shortDate(derived)). Trays are assumed to "
            + "change every \(daysPerTray) days from the treatment start."
        )
      }
    } else {
      Text("Changing a tray resets its start date to the day you record the change.")
    }
  }

  private var derivedTrayStartDate: Date? {
    PlanDates.currentTrayStartDate(
      treatmentStartDate: treatmentStartDate,
      currentTray: currentTray,
      daysPerTray: daysPerTray,
      calendar: Calendar.current
    )
  }

  private func shortDate(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .omitted)
  }

  private func syncDates(to anchor: DateAnchor) {
    let calendar = Calendar.current
    switch anchor {
    case .treatmentStart:
      if let start = PlanDates.treatmentStartDate(
        currentTrayStartDate: trayStartDate,
        currentTray: currentTray,
        daysPerTray: daysPerTray,
        calendar: calendar
      ) {
        treatmentStartDate = start
      }
    case .currentTrayStart:
      if let start = PlanDates.currentTrayStartDate(
        treatmentStartDate: treatmentStartDate,
        currentTray: currentTray,
        daysPerTray: daysPerTray,
        calendar: calendar
      ) {
        trayStartDate = start
      }
    }
  }

  private var reminderSection: some View {
    Section {
      Toggle("Change-day reminder", isOn: $reminderEnabled)
      if reminderEnabled {
        DatePicker("Remind me at", selection: $reminderTime, displayedComponents: .hourAndMinute)
      }
    } header: {
      Text("Reminder")
    } footer: {
      Text("One local notification on change day. Nothing leaves your iPhone.")
    }
  }

  private var deleteSection: some View {
    Section {
      Button("Delete plan", role: .destructive) {
        isConfirmingDelete = true
      }
    }
  }

  @MainActor
  private func save() {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
    let completedOn = mode == .edit ? store.plan?.completedOn : nil

    let tray = min(currentTray, totalTrays)
    let candidate: TreatmentPlan?
    switch dateAnchor {
    case .treatmentStart:
      candidate = TreatmentPlan(
        totalTrays: totalTrays,
        daysPerTray: daysPerTray,
        currentTray: tray,
        treatmentStartDate: treatmentStartDate,
        reminderHour: components.hour ?? 20,
        reminderMinute: components.minute ?? 0,
        notificationsEnabled: reminderEnabled,
        completedOn: completedOn
      )
    case .currentTrayStart:
      candidate = TreatmentPlan(
        totalTrays: totalTrays,
        daysPerTray: daysPerTray,
        currentTray: tray,
        trayStartDate: calendar.startOfDay(for: trayStartDate),
        reminderHour: components.hour ?? 20,
        reminderMinute: components.minute ?? 0,
        notificationsEnabled: reminderEnabled,
        completedOn: completedOn
      )
    }

    guard let plan = candidate else {
      errorMessage = "Check the tray count and days per tray."
      return
    }

    guard reminderEnabled else {
      store.save(plan)
      dismiss()
      return
    }

    isSaving = true
    Task {
      let granted = await NotificationScheduler.shared.ensureAuthorization()
      isSaving = false
      if granted {
        store.save(plan)
        dismiss()
      } else {
        var mutedPlan = plan
        mutedPlan.notificationsEnabled = false
        store.save(mutedPlan)
        showsPermissionAlert = true
      }
    }
  }

  @MainActor
  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }
}
