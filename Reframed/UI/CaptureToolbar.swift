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
    .background(ReframedColors.background)
    .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    .overlay(
      RoundedRectangle(cornerRadius: Radius.xl)
        .strokeBorder(ReframedColors.border, lineWidth: 0.5)
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
            .presentationBackground(ReframedColors.backgroundPopover)
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
            .presentationBackground(ReframedColors.backgroundPopover)
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
            .presentationBackground(ReframedColors.backgroundPopover)
        }
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
        .tint(ReframedColors.primaryText)
      Text("Processing...")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(ReframedColors.primaryText)
    }
    .frame(minWidth: 150, alignment: .center)
    .frame(height: 52)
    .padding(.horizontal, 8)
  }
}
