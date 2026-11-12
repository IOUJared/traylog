import Foundation

/// Parsing and clamping for free-form numeric entry.
public enum NumberEntry {
  /// Parses the digits in `text` and clamps the result into `range`.
  ///
  /// Non-digit characters are ignored; empty or unparseable text falls back to
  /// the provided value, clamped into the same range.
  public static func clampedValue(
    from text: String,
    fallback: Int,
    range: ClosedRange<Int>
  ) -> Int {
    let digits = text.filter(\.isNumber)
    let parsed = Int(digits) ?? fallback
    return min(max(parsed, range.lowerBound), range.upperBound)
  }
}
