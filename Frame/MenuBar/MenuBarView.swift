import SwiftUI

struct MenuBarView: View {
  let coordinator: CaptureCoordinator
  @Binding var isMenuPresented: Bool

  @State private var errorMessage: String?

  var body: some View {
    VStack(spacing: 12) {
      switch coordinator.ui.state {
      case .idle:
        idleView
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

  // MARK: - State Views

  private var idleView: some View {
    VStack(spacing: 8) {
      Text("Frame")
        .font(.headline)

      Button("New Recording") {
        isMenuPresented = false
        Task {
          do {
            try await coordinator.beginSelection()
          } catch {
            errorMessage = error.localizedDescription
          }
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)

      if let url = coordinator.ui.lastRecordingURL {
        Divider()
        HStack {
          Image(systemName: "film")
          Text(url.lastPathComponent)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer()
          Button {
            NSWorkspace.shared.activateFileViewerSelecting([url])
          } label: {
            Image(systemName: "folder")
          }
          .buttonStyle(.borderless)
        }
      }
    }
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
          Task { await coordinator.pauseRecording() }
        }
        .buttonStyle(.bordered)

        Button("Stop") {
          Task {
            do {
              try await coordinator.stopRecording()
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
          Task { await coordinator.resumeRecording() }
        }
        .buttonStyle(.bordered)

        Button("Stop") {
          Task {
            do {
              try await coordinator.stopRecording()
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
