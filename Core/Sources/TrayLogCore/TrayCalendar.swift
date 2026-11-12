import Foundation

/// One tray's planned wear window.
public struct TrayPeriod: Equatable, Sendable, Identifiable {
  /// The 1-based tray number.
  public let tray: Int
  /// The local start-of-day the tray begins.
  public let startDate: Date
  /// The day the tray's wear period ends and the next tray begins.
  public let changeDate: Date

  public var id: Int {
    tray
  }

  public init(tray: Int, startDate: Date, changeDate: Date) {
    self.tray = tray
    self.startDate = startDate
    self.changeDate = changeDate
  }
}

extension TreatmentPlan {
  /// Every tray's wear window, projected from the current tray's baseline.
  ///
  /// Trays before the current one are projected backwards by the same interval;
  /// a completed plan reports its final change on the recorded completion day.
  public func trayPeriods(calendar: Calendar = .current) -> [TrayPeriod] {
    let base = startOfTrayDay(calendar: calendar)
    let completionDay = completedOn.map { calendar.startOfDay(for: $0) }

    return (1...totalTrays).map { tray in
      let offset = (tray - currentTray) * daysPerTray
      let start = calendar.date(byAdding: .day, value: offset, to: base) ?? base
      var change = calendar.date(byAdding: .day, value: daysPerTray, to: start) ?? start
      if let completionDay, tray == totalTrays {
        change = completionDay
      }
      return TrayPeriod(tray: tray, startDate: start, changeDate: change)
    }
  }
}

/// Month layout helpers for the calendar grid.
public enum MonthGrid {
  /// The first day of the month containing `date`, shifted by `offset` months.
  public static func month(
    containing date: Date,
    offset: Int = 0,
    calendar: Calendar = .current
  ) -> Date {
    let start = calendar.dateInterval(of: .month, for: date)?.start
      ?? calendar.startOfDay(for: date)
    return calendar.date(byAdding: .month, value: offset, to: start) ?? start
  }

  /// Cells for a month laid out in weeks of seven, padded with `nil`.
  public static func cells(for month: Date, calendar: Calendar = .current) -> [Date?] {
    let start = calendar.dateInterval(of: .month, for: month)?.start
      ?? calendar.startOfDay(for: month)
    let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 0
    let weekday = calendar.component(.weekday, from: start)
    let leading = (weekday - calendar.firstWeekday + 7) % 7

    var cells: [Date?] = Array(repeating: nil, count: leading)
    for offset in 0..<dayCount {
      cells.append(calendar.date(byAdding: .day, value: offset, to: start))
    }
    while cells.count % 7 != 0 {
      cells.append(nil)
    }
    return cells
  }

  /// Weekday symbols rotated so the first entry matches `calendar.firstWeekday`.
  public static func weekdaySymbols(calendar: Calendar = .current) -> [String] {
    let symbols = calendar.veryShortWeekdaySymbols
    let first = calendar.firstWeekday - 1
    return Array(symbols[first...]) + Array(symbols[..<first])
  }
}
