import Foundation

/// User-facing countdown phrases shared by the app and the widget.
public enum CountdownLabel {
  /// A full status phrase, e.g. "Change in 9 days" or "2 days overdue".
  public static func changeStatus(daysUntilChange: Int) -> String {
    switch daysUntilChange {
    case ..<(-1):
      return "\(-daysUntilChange) days overdue"
    case -1:
      return "1 day overdue"
    case 0:
      return "Change due today"
    case 1:
      return "Change tomorrow"
    default:
      return "Change in \(daysUntilChange) days"
    }
  }

  /// A compact phrase for widgets, e.g. "in 9d" or "2d late".
  public static func compact(daysUntilChange: Int) -> String {
    switch daysUntilChange {
    case ..<(-1):
      return "\(-daysUntilChange)d late"
    case -1:
      return "1d late"
    case 0:
      return "today"
    case 1:
      return "tomorrow"
    default:
      return "in \(daysUntilChange)d"
    }
  }
}

/// Shared storage identifiers and serialization for the treatment plan.
public enum PlanStorage {
  /// The App Group that lets the app and its widget share one plan.
  public static let appGroupIdentifier = "group.com.ioujared.traylog"
  /// The key holding the encoded plan in the shared defaults.
  public static let defaultsKey = "treatmentPlan.v1"

  /// Encodes a plan for storage.
  public static func encode(_ plan: TreatmentPlan) -> Data? {
    try? JSONEncoder().encode(plan)
  }

  /// Decodes and re-validates a stored plan.
  public static func decode(_ data: Data) -> TreatmentPlan? {
    guard let plan = try? JSONDecoder().decode(TreatmentPlan.self, from: data) else {
      return nil
    }
    return plan.validated()
  }
}
