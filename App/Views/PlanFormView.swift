import SwiftUI
import TrayLogCore
import UIKit

struct PlanFormView: View {
  enum Mode {
    case create
    case edit
  }

  @Environment(PlanStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  private let mode: Mode

  @State private var totalTrays: Int
  @State private var daysPerTray: Int
  @State private var currentTray: Int
  @State private var trayStartDate: Date
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
    _trayStartDate = State(initialValue: plan?.trayStartDate ?? calendar.startOfDay(for: .now))
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
      Stepper(value: $totalTrays, in: 1...300) {
        LabeledContent("Total trays", value: "\(totalTrays)")
      }
      Stepper(value: $daysPerTray, in: 1...60) {
        LabeledContent("Days per tray", value: "\(daysPerTray)")
      }
      Stepper(value: $currentTray, in: 1...totalTrays) {
        LabeledContent("Current tray", value: "\(currentTray)")
      }
      DatePicker("Current tray started", selection: $trayStartDate, displayedComponents: .date)
    } header: {
      Text("Treatment")
    } footer: {
      Text("Changing a tray resets its start date to the day you record the change.")
    }
    .onChange(of: totalTrays) { _, newValue in
      if currentTray > newValue {
        currentTray = newValue
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

    guard
      let plan = TreatmentPlan(
        totalTrays: totalTrays,
        daysPerTray: daysPerTray,
        currentTray: min(currentTray, totalTrays),
        trayStartDate: calendar.startOfDay(for: trayStartDate),
        reminderHour: components.hour ?? 20,
        reminderMinute: components.minute ?? 0,
        notificationsEnabled: reminderEnabled,
        completedOn: completedOn
      )
    else {
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
