import XCTest

@testable import TrayLogCore

final class NumberEntryTests: XCTestCase {
  func testParsesDigits() {
    XCTAssertEqual(NumberEntry.clampedValue(from: "20", fallback: 1, range: 1...300), 20)
    XCTAssertEqual(NumberEntry.clampedValue(from: "007", fallback: 1, range: 1...300), 7)
  }

  func testIgnoresNonDigits() {
    XCTAssertEqual(NumberEntry.clampedValue(from: "1 4", fallback: 1, range: 1...60), 14)
    XCTAssertEqual(NumberEntry.clampedValue(from: "12abc", fallback: 1, range: 1...60), 12)
  }

  func testClampsToRange() {
    XCTAssertEqual(NumberEntry.clampedValue(from: "999", fallback: 1, range: 1...300), 300)
    XCTAssertEqual(NumberEntry.clampedValue(from: "0", fallback: 14, range: 1...60), 1)
  }

  func testEmptyAndUnparseableFallBack() {
    XCTAssertEqual(NumberEntry.clampedValue(from: "", fallback: 14, range: 1...60), 14)
    XCTAssertEqual(NumberEntry.clampedValue(from: "abc", fallback: 14, range: 1...60), 14)
  }

  func testFallbackIsClampedToo() {
    XCTAssertEqual(NumberEntry.clampedValue(from: "", fallback: 0, range: 1...60), 1)
    XCTAssertEqual(NumberEntry.clampedValue(from: "", fallback: 500, range: 1...300), 300)
  }
}
