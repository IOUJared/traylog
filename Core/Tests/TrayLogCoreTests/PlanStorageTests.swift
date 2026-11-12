import XCTest

@testable import TrayLogCore

final class CountdownLabelTests: XCTestCase {
  func testChangeStatusPhrases() {
    XCTAssertEqual(CountdownLabel.changeStatus(daysUntilChange: 9), "Change in 9 days")
    XCTAssertEqual(CountdownLabel.changeStatus(daysUntilChange: 2), "Change in 2 days")
    XCTAssertEqual(CountdownLabel.changeStatus(daysUntilChange: 1), "Change tomorrow")
    XCTAssertEqual(CountdownLabel.changeStatus(daysUntilChange: 0), "Change due today")
    XCTAssertEqual(CountdownLabel.changeStatus(daysUntilChange: -1), "1 day overdue")
    XCTAssertEqual(CountdownLabel.changeStatus(daysUntilChange: -3), "3 days overdue")
  }

  func testCompactPhrases() {
    XCTAssertEqual(CountdownLabel.compact(daysUntilChange: 9), "in 9d")
    XCTAssertEqual(CountdownLabel.compact(daysUntilChange: 1), "tomorrow")
    XCTAssertEqual(CountdownLabel.compact(daysUntilChange: 0), "today")
    XCTAssertEqual(CountdownLabel.compact(daysUntilChange: -1), "1d late")
    XCTAssertEqual(CountdownLabel.compact(daysUntilChange: -3), "3d late")
  }
}

final class PlanStorageTests: XCTestCase {
  private func makePlan() throws -> TreatmentPlan {
    try XCTUnwrap(
      TreatmentPlan(
        totalTrays: 20,
        daysPerTray: 14,
        currentTray: 4,
        trayStartDate: Date(timeIntervalSince1970: 1_767_225_600)
      )
    )
  }

  func testRoundTrip() throws {
    let plan = try makePlan()

    let data = try XCTUnwrap(PlanStorage.encode(plan))
    let decoded = try XCTUnwrap(PlanStorage.decode(data))

    XCTAssertEqual(decoded, plan)
  }

  func testDecodeRejectsInvalidStoredValues() {
    let invalidJSON = Data(
      """
      {"totalTrays":0,"daysPerTray":14,"currentTray":1,"trayStartDate":0,
      "reminderHour":20,"reminderMinute":0,"notificationsEnabled":true}
      """.utf8
    )

    XCTAssertNil(PlanStorage.decode(invalidJSON))
    XCTAssertNil(PlanStorage.decode(Data("not json".utf8)))
  }
}
