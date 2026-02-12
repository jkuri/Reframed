import AVFoundation
import SwiftUI

struct SettingsView: View {
  var options: RecordingOptions?

  @State private var outputFolder: String = ConfigService.shared.outputFolder
  @State private var cameraMaximumResolution: String = ConfigService.shared.cameraMaximumResolution
  @State private var projectFolder: String = ConfigService.shared.projectFolder
  @State private var appearance: String = ConfigService.shared.appearance
  @State private var showMicPopover = false
  @State private var showCameraPopover = false
  @Environment(\.colorScheme) private var colorScheme

  private let fpsOptions = [24, 30, 40, 50, 60]

  private var availableMicrophones: [AudioDevice] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    )
    return discovery.devices.map { AudioDevice(id: $0.uniqueID, name: $0.localizedName) }
  }

  private var availableCameras: [CaptureDevice] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .external],
      mediaType: .video,
      position: .unspecified
    )
    return discovery.devices.map { CaptureDevice(id: $0.uniqueID, name: $0.localizedName) }
  }

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 0) {
      header
      Divider().background(FrameColors.divider)
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          appearanceSection
          projectFolderSection
          outputSection
          recordingSection
          audioSection
          cameraSection
          optionsSection
        }
        .padding(24)
      }
    }
    .frame(width: 700, height: 800)
    .background(FrameColors.panelBackground)
  }

  private var header: some View {
    Text("Settings")
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(FrameColors.primaryText)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
  }

  private var appearanceSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Appearance")

      HStack(spacing: 4) {
        ForEach(["system", "light", "dark"], id: \.self) { mode in
          Button {
            appearance = mode
            ConfigService.shared.appearance = mode
            updateWindowBackgrounds()
          } label: {
            Text(mode.capitalized)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(FrameColors.primaryText)
              .padding(.horizontal, 14)
              .frame(height: 28)
              .background(appearance == mode ? FrameColors.selectedActive : FrameColors.fieldBackground)
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var projectFolderSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Project Folder")
      HStack(spacing: 8) {
        Text(projectFolder)
          .font(.system(size: 12))
          .foregroundStyle(FrameColors.primaryText)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(FrameColors.fieldBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6))

        Button("Browse") {
          chooseProjectFolder()
        }
        .buttonStyle(SettingsButtonStyle())
      }
    }
  }

  private var outputSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Output Folder")
      HStack(spacing: 8) {
        Text(outputFolder)
          .font(.system(size: 12))
          .foregroundStyle(FrameColors.primaryText)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(FrameColors.fieldBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6))

        Button("Browse") {
          chooseOutputFolder()
        }
        .buttonStyle(SettingsButtonStyle())
      }
    }
  }

  private var recordingSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Recording")

      HStack {
        Text("Frame Rate")
          .font(.system(size: 13))
          .foregroundStyle(FrameColors.primaryText)
        Spacer()
        HStack(spacing: 4) {
          ForEach(fpsOptions, id: \.self) { option in
            Button {
              options?.fps = option
            } label: {
              Text("\(option)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FrameColors.primaryText)
                .frame(width: 44, height: 28)
                .background(options?.fps == option ? FrameColors.selectedActive : FrameColors.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
      }

      HStack {
        Text("Timer Delay")
          .font(.system(size: 13))
          .foregroundStyle(FrameColors.primaryText)
        Spacer()
        HStack(spacing: 4) {
          ForEach(TimerDelay.allCases, id: \.self) { delay in
            Button {
              options?.timerDelay = delay
            } label: {
              Text(delay.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FrameColors.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(options?.timerDelay == delay ? FrameColors.selectedActive : FrameColors.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var microphoneLabel: String {
    guard let id = options?.selectedMicrophone?.id else { return "None" }
    return availableMicrophones.first { $0.id == id }?.name ?? "None"
  }

  private var audioSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Audio")

      settingsToggle(
        "Capture System Audio",
        isOn: Binding(
          get: { options?.captureSystemAudio ?? false },
          set: { options?.captureSystemAudio = $0 }
        )
      )

      HStack {
        Text("Microphone")
          .font(.system(size: 13))
          .foregroundStyle(FrameColors.primaryText)
        Spacer()
        devicePickerButton(label: microphoneLabel, isActive: $showMicPopover)
          .popover(isPresented: $showMicPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
              CheckmarkRow(title: "None", isSelected: options?.selectedMicrophone == nil) {
                options?.selectedMicrophone = nil
                showMicPopover = false
              }
              ForEach(availableMicrophones) { mic in
                CheckmarkRow(title: mic.name, isSelected: options?.selectedMicrophone?.id == mic.id) {
                  options?.selectedMicrophone = mic
                  showMicPopover = false
                }
              }
            }
            .padding(.vertical, 8)
            .frame(width: 220)
            .background(FrameColors.panelBackground)
          }
      }
      .padding(.horizontal, 10)
    }
  }

  private var cameraLabel: String {
    guard let id = options?.selectedCamera?.id else { return "None" }
    return availableCameras.first { $0.id == id }?.name ?? "None"
  }

  private var cameraSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Camera")

      HStack {
        Text("Camera Device")
          .font(.system(size: 13))
          .foregroundStyle(FrameColors.primaryText)
        Spacer()
        devicePickerButton(label: cameraLabel, isActive: $showCameraPopover)
          .popover(isPresented: $showCameraPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
              CheckmarkRow(title: "None", isSelected: options?.selectedCamera == nil) {
                options?.selectedCamera = nil
                showCameraPopover = false
              }
              ForEach(availableCameras) { cam in
                CheckmarkRow(title: cam.name, isSelected: options?.selectedCamera?.id == cam.id) {
                  options?.selectedCamera = cam
                  showCameraPopover = false
                }
              }
            }
            .padding(.vertical, 8)
            .frame(width: 220)
            .background(FrameColors.panelBackground)
          }
      }
      .padding(.horizontal, 10)

      HStack {
        Text("Maximum Resolution")
          .font(.system(size: 13))
          .foregroundStyle(FrameColors.primaryText)
        Spacer()
        HStack(spacing: 4) {
          ForEach(["720p", "1080p", "4K"], id: \.self) { res in
            Button {
              cameraMaximumResolution = res
              ConfigService.shared.cameraMaximumResolution = res
            } label: {
              Text(res)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FrameColors.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(cameraMaximumResolution == res ? FrameColors.selectedActive : FrameColors.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, 10)
    }
  }

  private var optionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Options")

      VStack(spacing: 2) {
        settingsToggle(
          "Remember Last Selection",
          isOn: Binding(
            get: { options?.rememberLastSelection ?? false },
            set: { options?.rememberLastSelection = $0 }
          )
        )
        settingsToggle(
          "Show Mouse Clicks",
          isOn: Binding(
            get: { options?.showMouseClicks ?? false },
            set: { options?.showMouseClicks = $0 }
          )
        )
      }
    }
  }

  private func devicePickerButton(label: String, isActive: Binding<Bool>) -> some View {
    Button {
      isActive.wrappedValue.toggle()
    } label: {
      HStack(spacing: 4) {
        Text(label)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(FrameColors.primaryText)
          .lineLimit(1)
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(FrameColors.dimLabel)
      }
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(FrameColors.fieldBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(FrameColors.dimLabel)
  }

  private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 13))
        .foregroundStyle(FrameColors.primaryText)
      Spacer()
      CustomToggle(isOn: isOn)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
  }

  private func updateWindowBackgrounds() {
    let bg = FrameColors.panelBackgroundNS
    for window in NSApp.windows {
      if window.titlebarAppearsTransparent {
        window.backgroundColor = bg
      }
    }
  }

  private func chooseProjectFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Select"

    if panel.runModal() == .OK, let url = panel.url {
      let path = url.path.replacingOccurrences(
        of: FileManager.default.homeDirectoryForCurrentUser.path,
        with: "~"
      )
      projectFolder = path
      ConfigService.shared.projectFolder = path
    }
  }

  private func chooseOutputFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Select"

    if panel.runModal() == .OK, let url = panel.url {
      let path = url.path.replacingOccurrences(
        of: FileManager.default.homeDirectoryForCurrentUser.path,
        with: "~"
      )
      outputFolder = path
      ConfigService.shared.outputFolder = path
    }
  }
}

private struct CustomToggle: View {
  @Binding var isOn: Bool

  var body: some View {
    Button {
      isOn.toggle()
    } label: {
      RoundedRectangle(cornerRadius: 8)
        .fill(isOn ? Color.accentColor : Color.gray.opacity(0.3))
        .frame(width: 34, height: 20)
        .overlay(alignment: isOn ? .trailing : .leading) {
          Circle()
            .fill(.white)
            .frame(width: 16, height: 16)
            .padding(2)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        }
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }
    .buttonStyle(.plain)
  }
}

private struct SettingsButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    let _ = colorScheme
    configuration.label
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(FrameColors.primaryText)
      .padding(.horizontal, 14)
      .frame(height: 30)
      .background(configuration.isPressed ? FrameColors.buttonPressed : FrameColors.buttonBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}
