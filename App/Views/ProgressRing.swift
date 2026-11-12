import SwiftUI

/// A circular progress ring with arbitrary centered content.
struct ProgressRing<Content: View>: View {
  let progress: Double
  private let content: () -> Content

  init(progress: Double, @ViewBuilder content: @escaping () -> Content) {
    self.progress = progress
    self.content = content
  }

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.15), lineWidth: 18)
      Circle()
        .trim(from: 0, to: min(max(progress, 0), 1))
        .stroke(
          LinearGradient(
            colors: [.trayAccent, .trayAccent.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          style: StrokeStyle(lineWidth: 18, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.4), value: progress)
      content()
    }
    .accessibilityElement(children: .combine)
  }
}
