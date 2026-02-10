import SwiftUI

struct MenuBarView: View {
  let session: SessionState

  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 12) {
      switch session.state {
      case .idle:
        EmptyView()
      case .selecting:
        selectingView
      case .recording(let startedAt):
        recordingView(startedAt: startedAt)
      case .paused(let elapsed):
        pausedView(elapsed: elapsed)
      case .processing:
        processingView
      case .editing:
        Text("Editing...")
      }

      if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
          .lineLimit(2)
      }
    }
    .padding(16)
    .frame(width: 240)
  }

  private var selectingView: some View {
    VStack(spacing: 8) {
      Text("Select a region...")
        .font(.headline)
      Text("Drag to select, ESC to cancel")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func recordingView(startedAt: Date) -> some View {
    VStack(spacing: 8) {
      RecordingTimerView(startedAt: startedAt)

      HStack(spacing: 8) {
        Button("Pause") {
          session.pauseRecording()
        }
        .buttonStyle(.bordered)

        Button("Stop") {
          Task {
            do {
              try await session.stopRecording()
            } catch {
              errorMessage = error.localizedDescription
            }
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
      }
    }
  }

  private func pausedView(elapsed: TimeInterval) -> some View {
    VStack(spacing: 8) {
      Text(formatElapsed(elapsed))
        .font(.system(.title2, design: .monospaced))
        .foregroundStyle(.orange)

      Text("Paused")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 8) {
        Button("Resume") {
          session.resumeRecording()
        }
        .buttonStyle(.bordered)

        Button("Stop") {
          Task {
            do {
              try await session.stopRecording()
            } catch {
              errorMessage = error.localizedDescription
            }
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
      }
    }
  }

  private var processingView: some View {
    VStack(spacing: 8) {
      ProgressView()
        .controlSize(.large)
      Text("Processing...")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private func formatElapsed(_ interval: TimeInterval) -> String {
    let total = Int(interval)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%02d:%02d", minutes, seconds)
  }
}
