import Foundation
import Observation
import TrayLogCore
import WidgetKit

/// Persists the treatment plan and keeps its single change-day reminder in sync.
@Observable
final class PlanStore {
  private(set) var plan: TreatmentPlan?

  private let defaults: UserDefaults
  private let calendar: Calendar
  private let now: () -> Date

  init(
    defaults: UserDefaults? = nil,
    calendar: Calendar = .current,
    now: @escaping () -> Date = Date.init
  ) {
    let sharedDefaults = defaults ?? UserDefaults(suiteName: PlanStorage.appGroupIdentifier)
    self.defaults = sharedDefaults ?? .standard
    self.calendar = calendar
    self.now = now
    self.plan = Self.loadPlan(from: self.defaults)

    if plan == nil, let legacyPlan = Self.loadPlan(from: .standard) {
      self.plan = legacyPlan
      persist()
      UserDefaults.standard.removeObject(forKey: PlanStorage.defaultsKey)
    }
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
    refreshWidgets()
  }

  /// Records a tray change today and updates the reminder.
  func advanceTray() {
    guard var updatedPlan = plan else { return }
    updatedPlan.advanceTray(on: now(), calendar: calendar)
    plan = updatedPlan
    persist()
    scheduleReminder(for: updatedPlan)
    refreshWidgets()
  }

  /// Removes the plan and its pending reminder.
  func clear() {
    plan = nil
    defaults.removeObject(forKey: PlanStorage.defaultsKey)
    Task { await NotificationScheduler.shared.schedule(nil) }
    refreshWidgets()
  }

  private func persist() {
    guard let plan else {
      defaults.removeObject(forKey: PlanStorage.defaultsKey)
      return
    }
    guard let data = PlanStorage.encode(plan) else { return }
    defaults.set(data, forKey: PlanStorage.defaultsKey)
  }

  private static func loadPlan(from defaults: UserDefaults) -> TreatmentPlan? {
    guard let data = defaults.data(forKey: PlanStorage.defaultsKey) else { return nil }
    return PlanStorage.decode(data)
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

  private func refreshWidgets() {
    WidgetCenter.shared.reloadAllTimelines()
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
