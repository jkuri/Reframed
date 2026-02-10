import SwiftUI

struct CaptureToolbar: View {
  let session: SessionState
  @State private var showOptions = false
  @State private var showRestartAlert = false

  var body: some View {
    HStack(spacing: 0) {
      switch session.state {
      case .recording(let startedAt):
        recordingControls(startedAt: startedAt, isPaused: false)
      case .paused(let elapsed):
        let pseudoStart = Date().addingTimeInterval(-elapsed)
        recordingControls(startedAt: pseudoStart, isPaused: true)
      case .processing:
        processingContent
      default:
        modeSelectionContent
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(FrameColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(FrameColors.subtleBorder, lineWidth: 0.5)
    )
    .alert("Restart Recording?", isPresented: $showRestartAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Restart", role: .destructive) {
        session.restartRecording()
      }
    } message: {
      Text("This will discard the current recording and return to mode selection.")
    }
  }

  private var modeSelectionContent: some View {
    Group {
      Button {
        session.hideToolbar()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(FrameColors.tertiaryText)
          .frame(width: 36, height: 52)
      }
      .buttonStyle(.plain)

      ToolbarDivider()

      HStack(spacing: 2) {
        ModeButton(
          icon: "rectangle.inset.filled",
          label: "Display",
          isSelected: session.captureMode == .entireScreen
        ) {
          session.selectMode(.entireScreen)
        }

        ModeButton(
          icon: "macwindow",
          label: "Window",
          isSelected: session.captureMode == .selectedWindow
        ) {
          session.selectMode(.selectedWindow)
        }

        ModeButton(
          icon: "rectangle.dashed",
          label: "Area",
          isSelected: session.captureMode == .selectedArea
        ) {
          session.selectMode(.selectedArea)
        }
      }

      ToolbarDivider()

      Button {
        showOptions.toggle()
      } label: {
        HStack(spacing: 4) {
          Text("Options")
            .font(.system(size: 13, weight: .medium))
          Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(FrameColors.primaryText)
        .padding(.horizontal, 14)
        .frame(height: 52)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showOptions, arrowEdge: .bottom) {
        OptionsPopover(options: session.options)
      }

      ToolbarDivider()

      Button {
        session.openSettings()
      } label: {
        Image(systemName: "gearshape")
          .font(.system(size: 16))
          .foregroundStyle(FrameColors.secondaryText)
          .frame(width: 36, height: 52)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  private func recordingControls(startedAt: Date, isPaused: Bool) -> some View {
    Group {
      Circle()
        .fill(isPaused ? Color.orange : Color.red)
        .frame(width: 10, height: 10)
        .padding(.leading, 4)

      CompactTimerView(startedAt: startedAt, frozen: isPaused)
        .padding(.horizontal, 10)

      if session.options.captureSystemAudio || session.options.selectedMicrophone != nil || session.options.selectedCamera != nil {
        HStack(spacing: 6) {
          if session.options.captureSystemAudio {
            Image(systemName: "speaker.wave.2.fill")
              .font(.system(size: 11))
              .foregroundStyle(FrameColors.tertiaryText)
          }
          if session.options.selectedMicrophone != nil {
            Image(systemName: "mic.fill")
              .font(.system(size: 11))
              .foregroundStyle(FrameColors.tertiaryText)
          }
          if session.options.selectedCamera != nil {
            Image(systemName: "web.camera.fill")
              .font(.system(size: 11))
              .foregroundStyle(FrameColors.tertiaryText)
          }
        }
        .padding(.trailing, 2)
      }

      ToolbarDivider()

      if isPaused {
        ToolbarActionButton(icon: "play.fill", tooltip: "Resume") {
          session.resumeRecording()
        }
      } else {
        ToolbarActionButton(icon: "pause.fill", tooltip: "Pause") {
          session.pauseRecording()
        }
      }

      ToolbarActionButton(icon: "stop.fill", tooltip: "Stop") {
        Task {
          try? await session.stopRecording()
        }
      }

      ToolbarDivider()

      ToolbarActionButton(icon: "arrow.counterclockwise", tooltip: "Restart") {
        showRestartAlert = true
      }
    }
  }

  private var processingContent: some View {
    HStack(spacing: 8) {
      ProgressView()
        .controlSize(.small)
        .scaleEffect(0.8)
      Text("Processing...")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(FrameColors.primaryText)
    }
    .frame(height: 52)
    .padding(.horizontal, 8)
  }
}

private struct CompactTimerView: View {
  let startedAt: Date
  let frozen: Bool

  @State private var elapsed: TimeInterval = 0
  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    Text(formatted)
      .font(.system(size: 16, design: .monospaced))
      .foregroundStyle(FrameColors.primaryText)
      .onReceive(timer) { _ in
        guard !frozen else { return }
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

private struct ToolbarActionButton: View {
  let icon: String
  let tooltip: String
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: 15))
        .foregroundStyle(FrameColors.primaryText)
        .frame(width: 36, height: 36)
        .background(isHovered ? FrameColors.hoverBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help(tooltip)
  }
}

private struct ToolbarDivider: View {
  var body: some View {
    Rectangle()
      .fill(FrameColors.divider)
      .frame(width: 1, height: 32)
      .padding(.horizontal, 8)
  }
}
