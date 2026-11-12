import Foundation

/// A user-entered clear-aligner treatment plan.
///
/// A plan is a linear sequence of trays. Each tray is worn for `daysPerTray`
/// days starting on `trayStartDate`. Recording a tray change moves the
/// baseline to the day of the change, so early and late changes shift the rest
/// of the schedule instead of accumulating drift.
public struct TreatmentPlan: Codable, Equatable, Sendable {
  /// The supported range for `totalTrays`.
  public static let trayCountRange = 1...300
  /// The supported range for `daysPerTray`.
  public static let daysPerTrayRange = 1...60

  /// The number of trays in the whole treatment.
  public var totalTrays: Int
  /// The planned wear period of each tray, in days.
  public var daysPerTray: Int
  /// The 1-based tray the user is wearing now.
  public var currentTray: Int
  /// The day the current tray started.
  public var trayStartDate: Date
  /// The hour (0-23) of the change-day reminder.
  public var reminderHour: Int
  /// The minute (0-59) of the change-day reminder.
  public var reminderMinute: Int
  /// Whether change-day reminders are enabled.
  public var notificationsEnabled: Bool
  /// The day the final tray was recorded as finished, if it was.
  public var completedOn: Date?

  /// Creates a validated plan.
  ///
  /// Returns `nil` when any value falls outside its supported range.
  public init?(
    totalTrays: Int,
    daysPerTray: Int,
    currentTray: Int = 1,
    trayStartDate: Date,
    reminderHour: Int = 20,
    reminderMinute: Int = 0,
    notificationsEnabled: Bool = true,
    completedOn: Date? = nil
  ) {
    guard Self.trayCountRange.contains(totalTrays),
      Self.daysPerTrayRange.contains(daysPerTray),
      (1...totalTrays).contains(currentTray),
      (0...23).contains(reminderHour),
      (0...59).contains(reminderMinute)
    else {
      return nil
    }
    self.totalTrays = totalTrays
    self.daysPerTray = daysPerTray
    self.currentTray = currentTray
    self.trayStartDate = trayStartDate
    self.reminderHour = reminderHour
    self.reminderMinute = reminderMinute
    self.notificationsEnabled = notificationsEnabled
    self.completedOn = completedOn
  }

  /// Whether the final tray has been completed.
  public var isComplete: Bool {
    completedOn != nil
  }

  /// The number of trays left after the current one.
  public var remainingTrays: Int {
    isComplete ? 0 : max(totalTrays - currentTray, 0)
  }

  /// Re-validates a plan, for example after decoding persisted data.
  ///
  /// Returns `nil` when the stored values are out of range or inconsistent.
  public func validated() -> TreatmentPlan? {
    TreatmentPlan(
      totalTrays: totalTrays,
      daysPerTray: daysPerTray,
      currentTray: currentTray,
      trayStartDate: trayStartDate,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      notificationsEnabled: notificationsEnabled,
      completedOn: completedOn
    )
  }

  /// The local start-of-day for the current tray.
  public func startOfTrayDay(calendar: Calendar = .current) -> Date {
    calendar.startOfDay(for: trayStartDate)
  }

  /// The day the current tray's wear period ends.
  public func changeDate(calendar: Calendar = .current) -> Date {
    let start = startOfTrayDay(calendar: calendar)
    return calendar.date(byAdding: .day, value: daysPerTray, to: start) ?? start
  }

  /// Whole calendar days elapsed since the current tray started.
  ///
  /// The value is negative when the start date lies in the future.
  public func daysElapsedInTray(on date: Date, calendar: Calendar = .current) -> Int {
    calendar.dateComponents(
      [.day],
      from: startOfTrayDay(calendar: calendar),
      to: calendar.startOfDay(for: date)
    ).day ?? 0
  }

  /// The 1-based day number within the current tray, clamped to
  /// `1...daysPerTray`.
  public func dayNumberInTray(on date: Date, calendar: Calendar = .current) -> Int {
    let elapsed = daysElapsedInTray(on: date, calendar: calendar) + 1
    return min(max(elapsed, 1), daysPerTray)
  }

  /// Whole calendar days until the change day.
  ///
  /// `0` means the change is due today; negative values mean overdue.
  public func daysUntilChange(on date: Date, calendar: Calendar = .current) -> Int {
    let today = calendar.startOfDay(for: date)
    return calendar.dateComponents(
      [.day],
      from: today,
      to: changeDate(calendar: calendar)
    ).day ?? 0
  }

  /// Whether the current tray's wear period has ended and no change was recorded.
  public func isChangeDue(on date: Date, calendar: Calendar = .current) -> Bool {
    !isComplete && daysUntilChange(on: date, calendar: calendar) <= 0
  }

  /// Treatment progress in `0...1`, including partial days in the current tray.
  public func overallProgress(on date: Date, calendar: Calendar = .current) -> Double {
    guard !isComplete else { return 1 }
    let totalDays = totalTrays * daysPerTray
    guard totalDays > 0 else { return 0 }
    let elapsedInTray = min(
      max(daysElapsedInTray(on: date, calendar: calendar), 0),
      daysPerTray
    )
    let elapsed = (currentTray - 1) * daysPerTray + elapsedInTray
    return min(max(Double(elapsed) / Double(totalDays), 0), 1)
  }

  /// The projected final day if every remaining tray keeps its full period.
  public func projectedEndDate(calendar: Calendar = .current) -> Date {
    guard !isComplete else {
      return calendar.startOfDay(for: completedOn ?? trayStartDate)
    }
    let remainingPeriods = max(totalTrays - currentTray + 1, 1)
    let days = remainingPeriods * daysPerTray
    return calendar.date(
      byAdding: .day,
      value: days,
      to: startOfTrayDay(calendar: calendar)
    ) ?? changeDate(calendar: calendar)
  }

  /// Records a tray change on `date` and moves the baseline to that day.
  ///
  /// Returns `true` when this change completed the final tray. Calling it on a
  /// completed plan does nothing and returns `false`.
  @discardableResult
  public mutating func advanceTray(on date: Date, calendar: Calendar = .current) -> Bool {
    guard !isComplete else { return false }
    let day = calendar.startOfDay(for: date)
    trayStartDate = day
    if currentTray >= totalTrays {
      completedOn = day
      return true
    }
    currentTray += 1
    return false
  }

  /// The next reminder, or `nil` when reminders are off, the plan is complete,
  /// or this change day's reminder time has already passed.
  public func nextReminderDate(
    onOrAfter now: Date,
    calendar: Calendar = .current
  ) -> Date? {
    guard notificationsEnabled, !isComplete else { return nil }
    let day = changeDate(calendar: calendar)
    guard
      let fireDate = calendar.date(
        bySettingHour: reminderHour,
        minute: reminderMinute,
        second: 0,
        of: day
      )
    else {
      return nil
    }
    return fireDate > now ? fireDate : nil
  }
}
