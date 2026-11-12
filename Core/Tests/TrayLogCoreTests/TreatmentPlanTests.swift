import XCTest

@testable import TrayLogCore

final class TreatmentPlanTests: XCTestCase {
  private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
  }()

  private var newYork: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
    return calendar
  }

  private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 0,
    minute: Int = 0,
    calendar: Calendar? = nil
  ) -> Date {
    let calendar = calendar ?? utc
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
  }

  private func plan(
    totalTrays: Int = 20,
    daysPerTray: Int = 14,
    currentTray: Int = 1,
    start: Date? = nil,
    reminderHour: Int = 20,
    reminderMinute: Int = 0,
    notificationsEnabled: Bool = true
  ) throws -> TreatmentPlan {
    try XCTUnwrap(
      TreatmentPlan(
        totalTrays: totalTrays,
        daysPerTray: daysPerTray,
        currentTray: currentTray,
        trayStartDate: start ?? date(2026, 1, 5),
        reminderHour: reminderHour,
        reminderMinute: reminderMinute,
        notificationsEnabled: notificationsEnabled
      )
    )
  }

  private func assertProgress(
    _ plan: TreatmentPlan,
    on day: Date,
    equals expected: Double,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      plan.overallProgress(on: day, calendar: utc),
      expected,
      accuracy: 0.0001,
      file: file,
      line: line
    )
  }

  // MARK: - Schedule

  func testChangeDateAddsDaysPerTrayToStartOfDay() throws {
    let plan = try plan(daysPerTray: 14, start: date(2026, 1, 5, hour: 15, minute: 30))

    XCTAssertEqual(plan.startOfTrayDay(calendar: utc), date(2026, 1, 5))
    XCTAssertEqual(plan.changeDate(calendar: utc), date(2026, 1, 19))
  }

  func testDayNumberStartsAtOneAndClamps() throws {
    let plan = try plan(daysPerTray: 14, start: date(2026, 1, 5))

    XCTAssertEqual(plan.dayNumberInTray(on: date(2026, 1, 5), calendar: utc), 1)
    XCTAssertEqual(plan.dayNumberInTray(on: date(2026, 1, 6), calendar: utc), 2)
    XCTAssertEqual(plan.dayNumberInTray(on: date(2026, 1, 18), calendar: utc), 14)
    XCTAssertEqual(plan.dayNumberInTray(on: date(2026, 2, 1), calendar: utc), 14)
    XCTAssertEqual(plan.dayNumberInTray(on: date(2026, 1, 1), calendar: utc), 1)
  }

  func testDaysUntilChangeCountsCalendarDays() throws {
    let plan = try plan(daysPerTray: 14, start: date(2026, 1, 5))

    XCTAssertEqual(plan.daysUntilChange(on: date(2026, 1, 5), calendar: utc), 14)
    XCTAssertEqual(plan.daysUntilChange(on: date(2026, 1, 18), calendar: utc), 1)
    XCTAssertEqual(plan.daysUntilChange(on: date(2026, 1, 19), calendar: utc), 0)
    XCTAssertEqual(plan.daysUntilChange(on: date(2026, 1, 22), calendar: utc), -3)
  }

  func testDayMathSurvivesDaylightSavingChanges() throws {
    let calendar = newYork
    let spring = try plan(
      daysPerTray: 14,
      start: date(2026, 3, 1, calendar: calendar)
    )
    XCTAssertEqual(spring.changeDate(calendar: calendar), date(2026, 3, 15, calendar: calendar))
    XCTAssertEqual(
      spring.dayNumberInTray(on: date(2026, 3, 8, calendar: calendar), calendar: calendar),
      8
    )
    XCTAssertEqual(
      spring.daysUntilChange(on: date(2026, 3, 7, calendar: calendar), calendar: calendar),
      8
    )
    XCTAssertEqual(
      spring.daysElapsedInTray(on: date(2026, 3, 15, calendar: calendar), calendar: calendar),
      14
    )

    let fall = try plan(
      daysPerTray: 14,
      start: date(2026, 10, 18, calendar: calendar)
    )
    XCTAssertEqual(fall.changeDate(calendar: calendar), date(2026, 11, 1, calendar: calendar))
    XCTAssertEqual(
      fall.dayNumberInTray(on: date(2026, 11, 1, calendar: calendar), calendar: calendar),
      14
    )
  }

  func testOverduePlanIsDueAndClampsProgress() throws {
    let plan = try plan(totalTrays: 10, daysPerTray: 10, start: date(2026, 1, 1))
    let overdueDay = date(2026, 1, 25)

    XCTAssertTrue(plan.isChangeDue(on: overdueDay, calendar: utc))
    XCTAssertFalse(plan.isChangeDue(on: date(2026, 1, 10), calendar: utc))
    XCTAssertEqual(plan.overallProgress(on: overdueDay, calendar: utc), 0.1, accuracy: 0.0001)
  }

  func testOverallProgressUsesWholeTrays() throws {
    let firstTray = try plan(totalTrays: 10, daysPerTray: 10, start: date(2026, 1, 1))
    assertProgress(firstTray, on: date(2026, 1, 1), equals: 0)
    assertProgress(firstTray, on: date(2026, 1, 6), equals: 0.05)

    let fifthTray = try plan(
      totalTrays: 10,
      daysPerTray: 10,
      currentTray: 5,
      start: date(2026, 1, 1)
    )
    assertProgress(fifthTray, on: date(2026, 1, 1), equals: 0.4)
    assertProgress(fifthTray, on: date(2026, 1, 9), equals: 0.48)
    assertProgress(fifthTray, on: date(2026, 1, 10), equals: 0.49)

    let lastTray = try plan(
      totalTrays: 10,
      daysPerTray: 10,
      currentTray: 10,
      start: date(2026, 1, 1)
    )
    assertProgress(lastTray, on: date(2026, 1, 10), equals: 0.99)
    assertProgress(lastTray, on: date(2026, 1, 11), equals: 1)
  }

  func testProjectedEndDateCountsRemainingPeriods() throws {
    let plan = try plan(totalTrays: 10, daysPerTray: 10, start: date(2026, 1, 1))

    XCTAssertEqual(
      plan.projectedEndDate(calendar: utc),
      date(2026, 1, 1).addingTimeInterval(100 * 24 * 60 * 60)
    )
  }

  // MARK: - Tray changes

  func testAdvanceTrayMovesToNextTrayAndResetsBaseline() throws {
    var plan = try plan(daysPerTray: 14, start: date(2026, 1, 5))

    plan.advanceTray(on: date(2026, 1, 12), calendar: utc)

    XCTAssertEqual(plan.currentTray, 2)
    XCTAssertEqual(plan.startOfTrayDay(calendar: utc), date(2026, 1, 12))
    XCTAssertEqual(plan.changeDate(calendar: utc), date(2026, 1, 26))
    XCTAssertFalse(plan.isComplete)
  }

  func testAdvanceLastTrayCompletesPlan() throws {
    var plan = try plan(totalTrays: 3, daysPerTray: 7, currentTray: 3, start: date(2026, 1, 1))

    let completed = plan.advanceTray(on: date(2026, 1, 10), calendar: utc)

    XCTAssertTrue(completed)
    XCTAssertTrue(plan.isComplete)
    XCTAssertEqual(plan.completedOn, date(2026, 1, 10))
    XCTAssertEqual(plan.overallProgress(on: date(2026, 2, 1), calendar: utc), 1)
    XCTAssertEqual(plan.remainingTrays, 0)
  }

  func testAdvanceAfterCompletionIsNoOp() throws {
    var plan = try plan(totalTrays: 2, daysPerTray: 7, currentTray: 2, start: date(2026, 1, 1))
    plan.advanceTray(on: date(2026, 1, 8), calendar: utc)

    let changedAgain = plan.advanceTray(on: date(2026, 1, 20), calendar: utc)

    XCTAssertFalse(changedAgain)
    XCTAssertEqual(plan.completedOn, date(2026, 1, 8))
  }

  func testAdvanceOnRecordedDayShiftsScheduleWithoutDrift() throws {
    var plan = try plan(daysPerTray: 14, start: date(2026, 1, 1))
    let lateChange = date(2026, 1, 20)

    plan.advanceTray(on: lateChange, calendar: utc)

    XCTAssertEqual(plan.changeDate(calendar: utc), date(2026, 2, 3))
    XCTAssertEqual(plan.daysUntilChange(on: lateChange, calendar: utc), 14)
  }

  // MARK: - Reminders

  func testReminderUsesChangeDayAtRequestedTime() throws {
    let plan = try plan(
      daysPerTray: 14,
      start: date(2026, 1, 5),
      reminderHour: 20,
      reminderMinute: 30
    )

    let reminder = plan.nextReminderDate(onOrAfter: date(2026, 1, 10), calendar: utc)

    XCTAssertEqual(reminder, date(2026, 1, 19, hour: 20, minute: 30))
  }

  func testReminderIsNilWhenDisabledCompleteOrPast() throws {
    let past = date(2026, 1, 19, hour: 21)

    let disabled = try plan(notificationsEnabled: false)
    XCTAssertNil(disabled.nextReminderDate(onOrAfter: date(2026, 1, 10), calendar: utc))

    var complete = try plan(totalTrays: 1)
    complete.advanceTray(on: date(2026, 1, 10), calendar: utc)
    XCTAssertNil(complete.nextReminderDate(onOrAfter: date(2026, 1, 10), calendar: utc))

    let overdue = try plan()
    XCTAssertNil(overdue.nextReminderDate(onOrAfter: past, calendar: utc))
  }

  // MARK: - Validation and persistence

  func testValidationRejectsOutOfRangeValues() {
    let start = date(2026, 1, 5)

    XCTAssertNil(TreatmentPlan(totalTrays: 0, daysPerTray: 14, trayStartDate: start))
    XCTAssertNil(TreatmentPlan(totalTrays: 301, daysPerTray: 14, trayStartDate: start))
    XCTAssertNil(TreatmentPlan(totalTrays: 10, daysPerTray: 0, trayStartDate: start))
    XCTAssertNil(TreatmentPlan(totalTrays: 10, daysPerTray: 61, trayStartDate: start))
    XCTAssertNil(
      TreatmentPlan(totalTrays: 10, daysPerTray: 14, currentTray: 11, trayStartDate: start)
    )
    XCTAssertNil(
      TreatmentPlan(totalTrays: 10, daysPerTray: 14, trayStartDate: start, reminderHour: 24)
    )
    XCTAssertNil(
      TreatmentPlan(totalTrays: 10, daysPerTray: 14, trayStartDate: start, reminderMinute: 60)
    )
  }

  func testValidationAcceptsBoundaries() throws {
    let start = date(2026, 1, 5)

    XCTAssertNotNil(
      TreatmentPlan(
        totalTrays: 1,
        daysPerTray: 1,
        trayStartDate: start,
        reminderHour: 0,
        reminderMinute: 0
      )
    )
    XCTAssertNotNil(
      TreatmentPlan(
        totalTrays: 300,
        daysPerTray: 60,
        trayStartDate: start,
        reminderHour: 23,
        reminderMinute: 59
      )
    )
  }

  func testValidatedRejectsMutatedInvalidPlan() throws {
    var plan = try plan()
    plan.totalTrays = 0

    XCTAssertNil(plan.validated())
  }

  func testCodableRoundTripPreservesCompletion() throws {
    var plan = try plan(totalTrays: 2, daysPerTray: 7, currentTray: 2, start: date(2026, 1, 1))
    plan.advanceTray(on: date(2026, 1, 8), calendar: utc)

    let data = try JSONEncoder().encode(plan)
    let decoded = try JSONDecoder().decode(TreatmentPlan.self, from: data)

    XCTAssertEqual(decoded, plan)
    XCTAssertEqual(decoded.completedOn, date(2026, 1, 8))
  }
}
