import Foundation

/// Conversions between the treatment-start date and the current tray's start.
public enum PlanDates {
  /// Derives the current tray's start from the day the treatment began.
  public static func currentTrayStartDate(
    treatmentStartDate: Date,
    currentTray: Int,
    daysPerTray: Int,
    calendar: Calendar = .current
  ) -> Date? {
    let offset = (currentTray - 1) * daysPerTray
    return calendar.date(
      byAdding: .day,
      value: offset,
      to: calendar.startOfDay(for: treatmentStartDate)
    )
  }

  /// Derives the treatment start from the current tray's start.
  public static func treatmentStartDate(
    currentTrayStartDate: Date,
    currentTray: Int,
    daysPerTray: Int,
    calendar: Calendar = .current
  ) -> Date? {
    let offset = -((currentTray - 1) * daysPerTray)
    return calendar.date(
      byAdding: .day,
      value: offset,
      to: calendar.startOfDay(for: currentTrayStartDate)
    )
  }
}

extension TreatmentPlan {
  /// Creates a plan from the day the whole treatment started.
  ///
  /// The current tray's start is calculated by assuming every earlier tray ran
  /// for its full `daysPerTray` period.
  public init?(
    totalTrays: Int,
    daysPerTray: Int,
    currentTray: Int,
    treatmentStartDate: Date,
    reminderHour: Int = 20,
    reminderMinute: Int = 0,
    notificationsEnabled: Bool = true,
    completedOn: Date? = nil,
    calendar: Calendar = .current
  ) {
    guard
      let trayStart = PlanDates.currentTrayStartDate(
        treatmentStartDate: treatmentStartDate,
        currentTray: currentTray,
        daysPerTray: daysPerTray,
        calendar: calendar
      )
    else {
      return nil
    }
    self.init(
      totalTrays: totalTrays,
      daysPerTray: daysPerTray,
      currentTray: currentTray,
      trayStartDate: trayStart,
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      notificationsEnabled: notificationsEnabled,
      completedOn: completedOn
    )
  }

  /// The projected day the whole treatment started.
  public func treatmentStartDate(calendar: Calendar = .current) -> Date {
    PlanDates.treatmentStartDate(
      currentTrayStartDate: trayStartDate,
      currentTray: currentTray,
      daysPerTray: daysPerTray,
      calendar: calendar
    ) ?? startOfTrayDay(calendar: calendar)
  }
}
