import Foundation
import Observation
import TrayLogCore

/// Persists the treatment plan and keeps its single change-day reminder in sync.
@Observable
final class PlanStore {
  private static let storageKey = "treatmentPlan.v1"

  private(set) var plan: TreatmentPlan?

  private let defaults: UserDefaults
  private let calendar: Calendar
  private let now: () -> Date

  init(
    defaults: UserDefaults = .standard,
    calendar: Calendar = .current,
    now: @escaping () -> Date = Date.init
  ) {
    self.defaults = defaults
    self.calendar = calendar
    self.now = now
    self.plan = Self.loadPlan(from: defaults)
  }

  /// The current instant, injected for testability.
  var today: Date {
    now()
  }

  /// Saves a plan, normalizes its start date, and replaces the pending reminder.
  func save(_ newPlan: TreatmentPlan) {
    var plan = newPlan
    plan.trayStartDate = calendar.startOfDay(for: plan.trayStartDate)
    self.plan = plan
    persist()
    scheduleReminder(for: plan)
  }

  /// Records a tray change today and updates the reminder.
  func advanceTray() {
    guard var updatedPlan = plan else { return }
    updatedPlan.advanceTray(on: now(), calendar: calendar)
    plan = updatedPlan
    persist()
    scheduleReminder(for: updatedPlan)
  }

  /// Removes the plan and its pending reminder.
  func clear() {
    plan = nil
    defaults.removeObject(forKey: Self.storageKey)
    Task { await NotificationScheduler.shared.schedule(nil) }
  }

  private func persist() {
    guard let plan else {
      defaults.removeObject(forKey: Self.storageKey)
      return
    }
    guard let data = try? JSONEncoder().encode(plan) else { return }
    defaults.set(data, forKey: Self.storageKey)
  }

  private static func loadPlan(from defaults: UserDefaults) -> TreatmentPlan? {
    guard
      let data = defaults.data(forKey: storageKey),
      let decoded = try? JSONDecoder().decode(TreatmentPlan.self, from: data)
    else {
      return nil
    }
    return decoded.validated()
  }

  private func scheduleReminder(for plan: TreatmentPlan) {
    let fireDate = plan.nextReminderDate(onOrAfter: now(), calendar: calendar)
    let reminder = fireDate.map {
      ChangeReminder(
        fireDate: $0,
        title: reminderTitle(for: plan),
        body: reminderBody(for: plan)
      )
    }
    Task { await NotificationScheduler.shared.schedule(reminder) }
  }

  private func reminderTitle(for plan: TreatmentPlan) -> String {
    if plan.currentTray >= plan.totalTrays {
      return "Final tray complete"
    }
    return "Time for tray \(plan.currentTray + 1)"
  }

  private func reminderBody(for plan: TreatmentPlan) -> String {
    if plan.currentTray >= plan.totalTrays {
      return "That was tray \(plan.totalTrays) of \(plan.totalTrays). "
        + "Check your fit and follow up with your orthodontist."
    }
    return "Move from tray \(plan.currentTray) to tray \(plan.currentTray + 1) "
      + "when your tray fits well."
  }
}
