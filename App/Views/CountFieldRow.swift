import SwiftUI
import TrayLogCore

/// A labelled number with a text field and minus/plus buttons.
///
/// Typing a valid in-range number updates the binding live; leaving the field
/// (or stepping) clamps out-of-range and empty input.
struct CountFieldRow: View {
  let title: String
  @Binding var value: Int
  let range: ClosedRange<Int>

  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 12) {
      Text(title)
      Spacer(minLength: 8)
      TextField("", text: $text)
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
        .frame(width: 56)
        .focused($isFocused)
        .accessibilityLabel(title)
        .onChange(of: text) { _, newValue in
          let digits = newValue.filter(\.isNumber)
          if digits != newValue {
            text = digits
            return
          }
          if let parsed = Int(digits), range.contains(parsed) {
            value = parsed
          }
        }
        .onChange(of: isFocused) { _, focused in
          if !focused {
            commit()
          }
        }

      Button {
        step(-1)
      } label: {
        Image(systemName: "minus.circle.fill")
          .font(.title3)
      }
      .buttonStyle(.borderless)
      .disabled(value <= range.lowerBound)
      .accessibilityLabel("Decrease \(title)")

      Button {
        step(1)
      } label: {
        Image(systemName: "plus.circle.fill")
          .font(.title3)
      }
      .buttonStyle(.borderless)
      .disabled(value >= range.upperBound)
      .accessibilityLabel("Increase \(title)")
    }
    .onAppear {
      text = String(value)
    }
    .onChange(of: value) { _, newValue in
      if !isFocused {
        text = String(newValue)
      }
    }
  }

  private func commit() {
    let clamped = NumberEntry.clampedValue(from: text, fallback: value, range: range)
    value = clamped
    text = String(clamped)
  }

  private func step(_ delta: Int) {
    isFocused = false
    let base = NumberEntry.clampedValue(from: text, fallback: value, range: range)
    value = min(max(base + delta, range.lowerBound), range.upperBound)
    text = String(value)
  }
}
