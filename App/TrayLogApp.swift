import SwiftUI
import TrayLogCore

@main
struct TrayLogApp: App {
  @State private var store = PlanStore()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(store)
        .tint(.trayAccent)
    }
  }
}
