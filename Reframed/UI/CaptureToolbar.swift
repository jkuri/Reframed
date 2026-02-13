import SwiftUI

struct CaptureToolbar: View {
  let session: SessionState
  @State private var showOptions = false
  @State private var showSettings = false
  @State private var showRestartAlert = false
  @State private var showDevicePopover = false

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    HStack(spacing: 0) {
      switch session.state {
      case .countdown(let remaining):
        countdownContent(remaining: remaining)
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
    .background(ReframedColors.panelBackground)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(ReframedColors.subtleBorder, lineWidth: 0.5)
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
    HoverEffectScope {
      HStack(spacing: 0) {
        Button {
          session.hideToolbar()
        } label: {
          VStack(spacing: 3) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 18))
              .foregroundStyle(ReframedColors.primaryText)
            Text("Close")
              .font(.system(size: 10))
              .foregroundStyle(ReframedColors.secondaryText)
          }
          .frame(width: 56, height: 52)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(id: "close")

        ToolbarDivider()

        HStack(spacing: 2) {
          ModeButton(
            icon: "rectangle.inset.filled",
            label: "Display",
            isSelected: session.captureMode == .entireScreen
          ) {
            session.selectMode(.entireScreen)
          }
          .hoverEffect(id: "mode.display")

          ModeButton(
            icon: "macwindow",
            label: "Window",
            isSelected: session.captureMode == .selectedWindow
          ) {
            session.selectMode(.selectedWindow)
          }
          .hoverEffect(id: "mode.window")

          ModeButton(
            icon: "rectangle.dashed",
            label: "Area",
            isSelected: session.captureMode == .selectedArea
          ) {
            session.selectMode(.selectedArea)
          }
          .hoverEffect(id: "mode.area")

          ModeButton(
            icon: "iphone",
            label: "Device",
            isSelected: session.captureMode == .device
          ) {
            showDevicePopover.toggle()
          }
          .hoverEffect(id: "mode.device")
          .popover(isPresented: $showDevicePopover, arrowEdge: .bottom) {
            DevicePopover { deviceId in
              showDevicePopover = false
              session.selectMode(.device)
              session.startDeviceRecordingWith(deviceId: deviceId)
            }
            .presentationBackground(ReframedColors.panelBackground)
          }
        }

        ToolbarDivider()

        HStack(spacing: 2) {
          ToolbarToggleButton(
            icon: "web.camera",
            activeIcon: "web.camera.fill",
            label: "Camera",
            isOn: session.isCameraOn,
            isAvailable: session.options.selectedCamera != nil,
            tooltip: session.options.selectedCamera != nil ? "Camera" : "Select a camera in Options",
            action: { session.toggleCamera() }
          )
          .hoverEffect(id: "toggle.camera")

          ToolbarToggleButton(
            icon: "mic",
            activeIcon: "mic.fill",
            label: "Mic",
            isOn: session.isMicrophoneOn,
            isAvailable: session.options.selectedMicrophone != nil,
            tooltip: session.options.selectedMicrophone != nil ? "Microphone" : "Select a microphone in Options",
            action: { session.toggleMicrophone() }
          )
          .hoverEffect(id: "toggle.mic")

          ToolbarToggleButton(
            icon: "speaker.wave.2",
            activeIcon: "speaker.wave.2.fill",
            label: "Audio",
            isOn: session.options.captureSystemAudio,
            isAvailable: true,
            tooltip: "System Audio",
            action: { session.options.captureSystemAudio.toggle() }
          )
          .hoverEffect(id: "toggle.audio")
        }

        ToolbarDivider()

        Button {
          showOptions.toggle()
        } label: {
          HStack(spacing: 4) {
            Text("Options")
              .font(.system(size: 12))
            Image(systemName: "chevron.down")
              .font(.system(size: 9, weight: .semibold))
          }
          .foregroundStyle(ReframedColors.primaryText)
          .padding(.horizontal, 14)
          .frame(height: 52)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(id: "btn.options")
        .popover(isPresented: $showOptions, arrowEdge: .bottom) {
          OptionsPopover(options: session.options)
            .presentationBackground(ReframedColors.panelBackground)
        }

        ToolbarDivider()

        Button {
          showSettings.toggle()
        } label: {
          VStack(spacing: 3) {
            Image(systemName: "gearshape")
              .font(.system(size: 18))
              .foregroundStyle(ReframedColors.primaryText)
            Text("Settings")
              .font(.system(size: 10))
              .foregroundStyle(ReframedColors.secondaryText)
          }
          .frame(width: 56, height: 52)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(id: "btn.settings")
        .popover(isPresented: $showSettings, arrowEdge: .bottom) {
          SettingsView(options: session.options)
            .presentationBackground(ReframedColors.panelBackground)
        }
      }
    }
  }

  private func countdownContent(remaining: Int) -> some View {
    Group {
      Image(systemName: "timer")
        .font(.system(size: 14))
        .foregroundStyle(ReframedColors.secondaryText)
        .padding(.leading, 4)

      Text("Recording in \(remaining)...")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(ReframedColors.primaryText)
        .padding(.horizontal, 10)
        .frame(height: 52)

      ToolbarDivider()

      ToolbarActionButton(icon: "xmark", tooltip: "Cancel") {
        session.cancelCountdown()
      }
    }
  }

  private func recordingControls(startedAt: Date, isPaused: Bool) -> some View {
    HStack(spacing: 0) {
      Circle()
        .fill(isPaused ? Color.orange : Color.red)
        .frame(width: 10, height: 10)
        .padding(.leading, 4)

      CompactTimerView(startedAt: startedAt, frozen: isPaused)
        .padding(.horizontal, 10)

      if session.options.captureSystemAudio || session.isMicrophoneOn || session.isCameraOn {
        HStack(spacing: 12) {
          if session.options.captureSystemAudio {
            AudioLevelIcon(icon: "speaker.wave.2.fill", level: session.systemAudioLevel)
          }
          if session.isMicrophoneOn {
            AudioLevelIcon(icon: "mic.fill", level: session.micAudioLevel)
          }
          if session.isCameraOn {
            VStack(spacing: 2) {
              Image(systemName: "web.camera.fill")
                .font(.system(size: 15))
                .foregroundStyle(ReframedColors.tertiaryText)
                .frame(height: 20)
              Color.clear.frame(height: 3)
            }
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
    .frame(height: 52)
  }

  private var processingContent: some View {
    HStack(spacing: 8) {
      ProgressView()
        .controlSize(.small)
        .scaleEffect(0.8)
      Text("Processing...")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(ReframedColors.primaryText)
    }
    .frame(minWidth: 150, alignment: .center)
    .frame(height: 52)
    .padding(.horizontal, 8)
  }
}

private struct CompactTimerView: View {
  let startedAt: Date
  let frozen: Bool

  var body: some View {
    if frozen {
      timerText(for: Date())
    } else {
      SwiftUI.TimelineView(.periodic(from: startedAt, by: 1)) { context in
        timerText(for: context.date)
      }
    }
  }

  private func timerText(for date: Date) -> some View {
    Text(formatDuration(seconds: Int(date.timeIntervalSince(startedAt))))
      .font(.system(size: 16, design: .monospaced))
      .foregroundStyle(ReframedColors.primaryText)
      .frame(minWidth: 80)
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
        .foregroundStyle(ReframedColors.primaryText)
        .frame(width: 36, height: 36)
        .background(isHovered ? ReframedColors.hoverBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
    .help(tooltip)
  }
}

private struct ToolbarToggleButton: View {
  let icon: String
  let activeIcon: String
  let label: String
  let isOn: Bool
  let isAvailable: Bool
  let tooltip: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: isOn ? activeIcon : icon)
          .font(.system(size: 18))
          .foregroundStyle(iconColor)
        Text(label)
          .font(.system(size: 10))
          .foregroundStyle(labelColor)
      }
      .frame(width: 56, height: 52)
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(!isAvailable)
    .help(tooltip)
  }

  private var iconColor: Color {
    if !isAvailable { return ReframedColors.tertiaryText.opacity(0.4) }
    return isOn ? ReframedColors.primaryText : ReframedColors.primaryText
  }

  private var labelColor: Color {
    if !isAvailable { return ReframedColors.tertiaryText.opacity(0.4) }
    return isOn ? ReframedColors.secondaryText : ReframedColors.secondaryText
  }

  private var background: Color {
    if !isAvailable { return Color.clear }
    if isOn { return ReframedColors.selectedBackground }
    return Color.clear
  }
}

private struct AudioLevelIcon: View {
  let icon: String
  let level: Float

  private let dotCount = 8
  private let thresholds: [Float] = [0.01, 0.03, 0.06, 0.10, 0.16, 0.24, 0.35, 0.50]

  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: 15))
        .foregroundStyle(ReframedColors.tertiaryText)
        .frame(height: 20)
      HStack(spacing: 1.5) {
        ForEach(0..<dotCount, id: \.self) { i in
          Circle()
            .fill(level > thresholds[i] ? Color.accentColor : ReframedColors.tertiaryText.opacity(0.2))
            .frame(width: 3, height: 3)
        }
      }
    }
  }
}

private struct ToolbarDivider: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme

    Rectangle()
      .fill(ReframedColors.divider)
      .frame(width: 1, height: 32)
      .padding(.horizontal, 8)
  }
}
