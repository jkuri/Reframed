import SwiftUI

struct RecordingTimerView: View {
  let startedAt: Date

  @State private var elapsed: TimeInterval = 0
  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    Text(formatted)
      .font(.system(.title2, design: .monospaced))
      .foregroundStyle(.red)
      .onReceive(timer) { _ in
        elapsed = Date().timeIntervalSince(startedAt)
      }
      .onAppear {
        elapsed = Date().timeIntervalSince(startedAt)
      }
  }

  private var formatted: String {
    let total = Int(elapsed)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
  }
}
