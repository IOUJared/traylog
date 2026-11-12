import XCTest

@testable import TrayLogCore

final class PlanDatesTests: XCTestCase {
  private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
  }()

  private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 0,
    calendar: Calendar? = nil
  ) -> Date {
    let calendar = calendar ?? utc
    return calendar.date(
      from: DateComponents(year: year, month: month, day: day, hour: hour)
    ) ?? Date(timeIntervalSince1970: 0)
  }

  func testCurrentTrayStartDerivesFromTreatmentStart() throws {
    let start = try XCTUnwrap(
      PlanDates.currentTrayStartDate(
        treatmentStartDate: date(2026, 1, 1),
        currentTray: 5,
        daysPerTray: 14,
        calendar: utc
      )
    )

    XCTAssertEqual(start, date(2026, 2, 26))
  }

  func testTrayOneStartsOnTreatmentStart() throws {
    let start = try XCTUnwrap(
      PlanDates.currentTrayStartDate(
        treatmentStartDate: date(2026, 1, 1, hour: 15),
        currentTray: 1,
        daysPerTray: 14,
        calendar: utc
      )
    )

    XCTAssertEqual(start, date(2026, 1, 1))
  }

  func testTreatmentStartInvertsCurrentTrayStart() throws {
    let currentStart = date(2026, 2, 26)

    let start = try XCTUnwrap(
      PlanDates.treatmentStartDate(
        currentTrayStartDate: currentStart,
        currentTray: 5,
        daysPerTray: 14,
        calendar: utc
      )
    )

    XCTAssertEqual(start, date(2026, 1, 1))
  }

  func testInitializerStoresDerivedTrayStart() throws {
    let plan = try XCTUnwrap(
      TreatmentPlan(
        totalTrays: 20,
        daysPerTray: 14,
        currentTray: 5,
        treatmentStartDate: date(2026, 1, 1),
        calendar: utc
      )
    )

    XCTAssertEqual(plan.startOfTrayDay(calendar: utc), date(2026, 2, 26))
    XCTAssertEqual(plan.treatmentStartDate(calendar: utc), date(2026, 1, 1))
  }

  func testRoundTripPreservesTrayStart() throws {
    let original = try XCTUnwrap(
      TreatmentPlan(
        totalTrays: 12,
        daysPerTray: 10,
        currentTray: 7,
        trayStartDate: date(2026, 4, 3)
      )
    )

    let rebuilt = try XCTUnwrap(
      TreatmentPlan(
        totalTrays: original.totalTrays,
        daysPerTray: original.daysPerTray,
        currentTray: original.currentTray,
        treatmentStartDate: original.treatmentStartDate(calendar: utc),
        calendar: utc
      )
    )

    XCTAssertEqual(rebuilt.startOfTrayDay(calendar: utc), original.startOfTrayDay(calendar: utc))
  }

  func testDerivationUsesCalendarDaysAcrossDST() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt

    let start = try XCTUnwrap(
      PlanDates.currentTrayStartDate(
        treatmentStartDate: date(2026, 3, 1, calendar: calendar),
        currentTray: 3,
        daysPerTray: 14,
        calendar: calendar
      )
    )

    XCTAssertEqual(start, date(2026, 3, 29, calendar: calendar))
    XCTAssertEqual(calendar.component(.hour, from: start), 0)
  }

  func testInitializerRejectsOutOfRangeTray() {
    XCTAssertNil(
      TreatmentPlan(
        totalTrays: 20,
        daysPerTray: 14,
        currentTray: 21,
        treatmentStartDate: date(2026, 1, 1)
      )
    )
    XCTAssertNil(
      TreatmentPlan(
        totalTrays: 20,
        daysPerTray: 0,
        currentTray: 1,
        treatmentStartDate: date(2026, 1, 1)
      )
    )
  }
}
