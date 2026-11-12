import XCTest

@testable import TrayLogCore

final class TrayCalendarTests: XCTestCase {
  private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    calendar.firstWeekday = 1
    return calendar
  }()

  private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    calendar: Calendar? = nil
  ) -> Date {
    let calendar = calendar ?? utc
    return calendar.date(from: DateComponents(year: year, month: month, day: day))
      ?? Date(timeIntervalSince1970: 0)
  }

  private func plan(
    totalTrays: Int = 20,
    daysPerTray: Int = 14,
    currentTray: Int = 4,
    start: Date? = nil
  ) throws -> TreatmentPlan {
    try XCTUnwrap(
      TreatmentPlan(
        totalTrays: totalTrays,
        daysPerTray: daysPerTray,
        currentTray: currentTray,
        trayStartDate: start ?? date(2026, 1, 1)
      )
    )
  }

  // MARK: - Tray periods

  func testPeriodsAnchorOnTheCurrentTray() throws {
    let plan = try plan()

    let periods = plan.trayPeriods(calendar: utc)

    XCTAssertEqual(periods.count, 20)
    XCTAssertEqual(periods[3].tray, 4)
    XCTAssertEqual(periods[3].startDate, date(2026, 1, 1))
    XCTAssertEqual(periods[3].changeDate, date(2026, 1, 15))
  }

  func testPeriodsChainWithoutGaps() throws {
    let plan = try plan()

    let periods = plan.trayPeriods(calendar: utc)

    for index in 1..<periods.count {
      XCTAssertEqual(periods[index].startDate, periods[index - 1].changeDate)
    }
  }

  func testPastPeriodsProjectBackwards() throws {
    let plan = try plan()

    let periods = plan.trayPeriods(calendar: utc)

    XCTAssertEqual(
      periods[0].startDate,
      utc.date(byAdding: .day, value: -3 * 14, to: date(2026, 1, 1))
    )
    XCTAssertEqual(
      periods[0].changeDate,
      utc.date(byAdding: .day, value: -2 * 14, to: date(2026, 1, 1))
    )
  }

  func testLastPeriodEndsAfterAllTrays() throws {
    let plan = try plan()

    let periods = plan.trayPeriods(calendar: utc)

    XCTAssertEqual(
      periods[19].changeDate,
      utc.date(byAdding: .day, value: 17 * 14, to: date(2026, 1, 1))
    )
  }

  func testCompletedPlanUsesRecordedCompletionDay() throws {
    var plan = try plan(totalTrays: 2, daysPerTray: 7, currentTray: 2, start: date(2026, 1, 1))
    plan.advanceTray(on: date(2026, 1, 10), calendar: utc)

    let periods = plan.trayPeriods(calendar: utc)

    XCTAssertEqual(periods[1].changeDate, date(2026, 1, 10))
  }

  func testPeriodsUseCalendarDaysAcrossDST() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
    calendar.firstWeekday = 1
    let plan = try plan(
      daysPerTray: 14,
      start: date(2026, 3, 1, calendar: calendar)
    )

    let periods = plan.trayPeriods(calendar: calendar)

    XCTAssertEqual(periods[3].changeDate, date(2026, 3, 15, calendar: calendar))
    XCTAssertEqual(periods[4].startDate, date(2026, 3, 15, calendar: calendar))
  }

  // MARK: - Month grid

  func testFebruary2026StartsOnSunday() {
    let cells = MonthGrid.cells(for: date(2026, 2, 1), calendar: utc)

    XCTAssertEqual(cells.count, 28)
    XCTAssertEqual(cells[0], date(2026, 2, 1))
    XCTAssertEqual(cells[27], date(2026, 2, 28))
  }

  func testMarch2026PadsTrailingWeek() {
    let cells = MonthGrid.cells(for: date(2026, 3, 1), calendar: utc)

    XCTAssertEqual(cells.count, 35)
    XCTAssertEqual(cells[0], date(2026, 3, 1))
    XCTAssertEqual(cells[30], date(2026, 3, 31))
    XCTAssertNil(cells[31])
    XCTAssertEqual(cells.compactMap { $0 }.count, 31)
  }

  func testMondayFirstWeekdayShiftsLeadingPadding() {
    var mondayFirst = utc
    mondayFirst.firstWeekday = 2

    let cells = MonthGrid.cells(for: date(2026, 3, 1), calendar: mondayFirst)

    XCTAssertEqual(cells.count, 42)
    XCTAssertEqual(cells.prefix(6).compactMap { $0 }.count, 0)
    XCTAssertEqual(cells[6], date(2026, 3, 1))
  }

  func testMonthShiftsAcrossYearBoundary() {
    XCTAssertEqual(
      MonthGrid.month(containing: date(2026, 12, 15), offset: 1, calendar: utc),
      date(2027, 1, 1)
    )
    XCTAssertEqual(
      MonthGrid.month(containing: date(2026, 1, 31), offset: -1, calendar: utc),
      date(2025, 12, 1)
    )
  }

  func testMonthGridHandlesDSTMonth() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
    calendar.firstWeekday = 1

    let cells = MonthGrid.cells(for: date(2026, 10, 1, calendar: calendar), calendar: calendar)

    XCTAssertEqual(cells.compactMap { $0 }.count, 31)
    XCTAssertEqual(cells.count % 7, 0)
    XCTAssertEqual(cells.compactMap { $0 }.last, date(2026, 10, 31, calendar: calendar))
  }

  func testWeekdaySymbolsRotateToFirstWeekday() {
    let sundayFirst = MonthGrid.weekdaySymbols(calendar: utc)
    var mondayFirst = utc
    mondayFirst.firstWeekday = 2
    let rotated = MonthGrid.weekdaySymbols(calendar: mondayFirst)

    XCTAssertEqual(sundayFirst.count, 7)
    XCTAssertEqual(rotated, Array(sundayFirst[1...]) + Array(sundayFirst[..<1]))
  }
}
