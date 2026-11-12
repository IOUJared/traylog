import Foundation
import TrayLogCore
import WidgetKit

/// One timeline entry: the plan as it should be read at `date`.
struct TrayEntry: TimelineEntry {
  let date: Date
  let plan: TreatmentPlan?
}

/// Builds a week of daily entries so the countdown rolls over at midnight.
struct TrayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TrayEntry {
    TrayEntry(date: Date(), plan: Self.samplePlan)
  }

  func getSnapshot(in context: Context, completion: @escaping (TrayEntry) -> Void) {
    if context.isPreview {
      completion(TrayEntry(date: Date(), plan: Self.samplePlan))
    } else {
      completion(TrayEntry(date: Date(), plan: WidgetPlan.load()))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TrayEntry>) -> Void) {
    let calendar = Calendar.current
    let now = Date()
    let plan = WidgetPlan.load()
    var entries: [TrayEntry] = []

    for offset in 0..<8 {
      guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
      let entryDate = offset == 0 ? now : calendar.startOfDay(for: day)
      entries.append(TrayEntry(date: entryDate, plan: plan))
    }

    let refresh = calendar.date(byAdding: .day, value: 8, to: now) ?? now
    completion(Timeline(entries: entries, policy: .after(refresh)))
  }

  private static var samplePlan: TreatmentPlan? {
    let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-4 * 86_400)
    return TreatmentPlan(
      totalTrays: 20,
      daysPerTray: 14,
      currentTray: 4,
      trayStartDate: start
    )
  }
}

/// Reads the plan the app writes into the shared App Group container.
enum WidgetPlan {
  static func load() -> TreatmentPlan? {
    guard
      let defaults = UserDefaults(suiteName: PlanStorage.appGroupIdentifier),
      let data = defaults.data(forKey: PlanStorage.defaultsKey)
    else {
      return nil
    }
    return PlanStorage.decode(data)
  }
}
