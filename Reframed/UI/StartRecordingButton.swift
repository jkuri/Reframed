import SwiftUI

struct StartRecordingButton: View {
  let delay: Int
  var onCountdownStart: (() -> Void)?
  var onCancel: (() -> Void)?
  let action: () -> Void

  @State private var remaining: Int?
  @State private var countdownTask: Task<Void, Never>?

  var body: some View {
    Button {
      if remaining != nil {
        countdownTask?.cancel()
        countdownTask = nil
        remaining = nil
        onCancel?()
        return
      }
      onCountdownStart?()
      guard delay > 0 else {
        action()
        return
      }
      startCountdown()
    } label: {
      HStack(spacing: 6) {
        if let remaining {
          Image(systemName: "timer")
          Text("Recording in \(remaining)...")
        } else {
          Image(systemName: "record.circle")
          Text("Start recording")
        }
      }
      .contentTransition(.numericText())
      .animation(.default, value: remaining)
    }
    .buttonStyle(PrimaryButtonStyle(size: .large, forceLightMode: true))
    .onDisappear {
      countdownTask?.cancel()
      countdownTask = nil
    }
  }

  private func startCountdown() {
    remaining = delay
    countdownTask = Task { @MainActor in
      var count = delay
      while count > 0 {
        try? await Task.sleep(for: .seconds(1))
        if Task.isCancelled { return }
        count -= 1
        if count > 0 {
          remaining = count
        }
      }
      remaining = nil
      countdownTask = nil
      action()
    }
  }
}
