import SwiftUI
import WidgetKit

@main
struct TrayLogWidgetBundle: WidgetBundle {
  var body: some Widget {
    TrayCountdownWidget()
  }
}

struct TrayCountdownWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "TrayCountdownWidget", provider: TrayProvider()) { entry in
      TrayWidgetView(entry: entry)
    }
    .configurationDisplayName("Tray countdown")
    .description("Your current tray and the days until your next change.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
  }
}
