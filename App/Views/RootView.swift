import SwiftUI

struct RootView: View {
  @Environment(PlanStore.self) private var store

  var body: some View {
    TabView {
      NavigationStack {
        Group {
          if store.plan == nil {
            EmptyPlanView()
          } else {
            TodayView()
          }
        }
        .navigationTitle("TrayLog")
        .navigationBarTitleDisplayMode(.inline)
      }
      .tabItem {
        Label("Today", systemImage: "sun.max")
      }

      NavigationStack {
        CalendarView()
      }
      .tabItem {
        Label("Calendar", systemImage: "calendar")
      }
    }
  }
}

private struct EmptyPlanView: View {
  @Environment(PlanStore.self) private var store
  @State private var isPresentingSetup = false

  var body: some View {
    ContentUnavailableView {
      Label("No plan yet", systemImage: "calendar.badge.clock")
    } description: {
      Text("Add your trays and wear schedule to see which tray is next.")
    } actions: {
      Button("Create plan") {
        isPresentingSetup = true
      }
      .buttonStyle(.borderedProminent)
    }
    .sheet(isPresented: $isPresentingSetup) {
      PlanFormView(mode: .create, plan: nil)
        .environment(store)
    }
  }
}
