import AVFoundation
import SwiftUI

private enum SettingsTab: String, CaseIterable {
  case general = "General"
  case recording = "Recording"
  case devices = "Devices"

  var icon: String {
    switch self {
    case .general: "gearshape"
    case .recording: "record.circle"
    case .devices: "mic.and.signal.meter"
    }
  }
}

struct SettingsView: View {
  var options: RecordingOptions?

  @State private var selectedTab: SettingsTab = .general
  @State private var outputFolder: String = ConfigService.shared.outputFolder
  @State private var cameraMaximumResolution: String = ConfigService.shared.cameraMaximumResolution
  @State private var projectFolder: String = ConfigService.shared.projectFolder
  @State private var appearance: String = ConfigService.shared.appearance
  @State private var showMicPopover = false
  @State private var showCameraPopover = false
  @State private var showColorPopover = false
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
      tabBar
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          switch selectedTab {
          case .general:
            generalContent
          case .recording:
            recordingContent
          case .devices:
            devicesContent
          }
        }
        .padding(24)
      }
    }
    .frame(width: 600, height: 520)
    .background(ReframedColors.panelBackground)
  }

  private var tabBar: some View {
    HoverEffectScope {
      HStack(spacing: 4) {
        ForEach(SettingsTab.allCases, id: \.self) { tab in
          Button {
            selectedTab = tab
          } label: {
            HStack(spacing: 6) {
              Image(systemName: tab.icon)
                .font(.system(size: 13))
              Text(tab.rawValue)
                .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selectedTab == tab ? ReframedColors.primaryText : ReframedColors.dimLabel)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(selectedTab == tab ? ReframedColors.selectedActive : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .hoverEffect(id: "settings.tab.\(tab.rawValue)")
        }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
    }
  }

  private var generalContent: some View {
    Group {
      appearanceSection
      projectFolderSection
      outputSection
      optionsSection
    }
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
              .foregroundStyle(ReframedColors.primaryText)
              .padding(.horizontal, 14)
              .frame(height: 28)
              .background(appearance == mode ? ReframedColors.selectedActive : ReframedColors.fieldBackground)
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
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(ReframedColors.fieldBackground)
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
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 7)
          .background(ReframedColors.fieldBackground)
          .clipShape(RoundedRectangle(cornerRadius: 6))

        Button("Browse") {
          chooseOutputFolder()
        }
        .buttonStyle(SettingsButtonStyle())
      }
    }
  }

  private var optionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Options")

      settingsToggle(
        "Remember Last Selection",
        isOn: Binding(
          get: { options?.rememberLastSelection ?? false },
          set: { options?.rememberLastSelection = $0 }
        )
      )
    }
  }

  private var recordingContent: some View {
    Group {
      frameRateSection
      timerDelaySection
      mouseClickSection
    }
  }

  private var frameRateSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Frame Rate")

      HStack {
        Text("FPS")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        HStack(spacing: 4) {
          ForEach(fpsOptions, id: \.self) { option in
            Button {
              options?.fps = option
            } label: {
              Text("\(option)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ReframedColors.primaryText)
                .frame(width: 44, height: 28)
                .background(options?.fps == option ? ReframedColors.selectedActive : ReframedColors.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, 10)
    }
  }

  private var timerDelaySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Timer Delay")

      HStack {
        Text("Countdown")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        HStack(spacing: 4) {
          ForEach(TimerDelay.allCases, id: \.self) { delay in
            Button {
              options?.timerDelay = delay
            } label: {
              Text(delay.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ReframedColors.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(options?.timerDelay == delay ? ReframedColors.selectedActive : ReframedColors.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, 10)
    }
  }

  private var clickColorDisplay: Color {
    if let cc = options?.mouseClickColor {
      return Color(cgColor: cc.cgColor)
    }
    return Color.accentColor
  }

  private var clickColorLabel: String {
    guard let cc = options?.mouseClickColor else { return "Neutral" }
    return TailwindColors.all.first { $0.color == cc }?.name ?? "Custom"
  }

  private var mouseClickSize: Binding<Double> {
    Binding(
      get: { Double(options?.mouseClickSize ?? 36) },
      set: { options?.mouseClickSize = Int($0) }
    )
  }

  private var mouseClickSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionLabel("Mouse Clicks")

      settingsToggle(
        "Show Mouse Clicks",
        isOn: Binding(
          get: { options?.showMouseClicks ?? false },
          set: { options?.showMouseClicks = $0 }
        )
      )

      if options?.showMouseClicks == true {
        VStack(spacing: 8) {
          HStack(spacing: 12) {
            Text("Color")
              .font(.system(size: 13))
              .foregroundStyle(ReframedColors.primaryText)
            colorPickerButton
            Spacer()
            Text("Size")
              .font(.system(size: 13))
              .foregroundStyle(ReframedColors.primaryText)
            Slider(value: mouseClickSize, in: 16...80, step: 1)
              .frame(width: 160)
            Text("\(Int(mouseClickSize.wrappedValue))pt")
              .font(.system(size: 13, weight: .medium).monospacedDigit())
              .foregroundStyle(ReframedColors.dimLabel)
              .frame(width: 36, alignment: .trailing)
          }
          MouseClickPreview(
            color: clickColorDisplay,
            size: CGFloat(mouseClickSize.wrappedValue)
          )
          .frame(maxWidth: .infinity)
          .frame(height: 100)
        }
        .padding(.horizontal, 10)
      }
    }
  }

  private var colorPickerButton: some View {
    Button {
      showColorPopover.toggle()
    } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(clickColorDisplay)
          .frame(width: 16, height: 16)
        Text(clickColorLabel)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(ReframedColors.dimLabel)
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(ReframedColors.fieldBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showColorPopover, arrowEdge: .bottom) {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ColorPresetRow(
            name: "Neutral",
            subtitle: "Match base color",
            color: .accentColor,
            isSelected: options?.mouseClickColor == nil
          ) {
            options?.mouseClickColor = nil
            showColorPopover = false
          }
          ForEach(TailwindColors.all) { preset in
            ColorPresetRow(
              name: preset.name,
              color: preset.swiftUIColor,
              isSelected: options?.mouseClickColor == preset.color
            ) {
              options?.mouseClickColor = preset.color
              showColorPopover = false
            }
          }
        }
        .padding(.vertical, 8)
      }
      .frame(width: 240)
      .frame(maxHeight: 360)
      .background(ReframedColors.panelBackground)
    }
    .presentationBackground(ReframedColors.panelBackground)
  }

  private var devicesContent: some View {
    Group {
      audioSection
      cameraSection
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
          .foregroundStyle(ReframedColors.primaryText)
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
            .background(ReframedColors.panelBackground)
          }
          .presentationBackground(ReframedColors.panelBackground)
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
          .foregroundStyle(ReframedColors.primaryText)
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
            .background(ReframedColors.panelBackground)
          }
          .presentationBackground(ReframedColors.panelBackground)
      }
      .padding(.horizontal, 10)

      HStack {
        Text("Maximum Resolution")
          .font(.system(size: 13))
          .foregroundStyle(ReframedColors.primaryText)
        Spacer()
        HStack(spacing: 4) {
          ForEach(["720p", "1080p", "4K"], id: \.self) { res in
            Button {
              cameraMaximumResolution = res
              ConfigService.shared.cameraMaximumResolution = res
            } label: {
              Text(res)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ReframedColors.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(cameraMaximumResolution == res ? ReframedColors.selectedActive : ReframedColors.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, 10)
    }
  }

  private func devicePickerButton(label: String, isActive: Binding<Bool>) -> some View {
    Button {
      isActive.wrappedValue.toggle()
    } label: {
      HStack(spacing: 4) {
        Text(label)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)
          .lineLimit(1)
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(ReframedColors.dimLabel)
      }
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(ReframedColors.fieldBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .buttonStyle(.plain)
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(ReframedColors.dimLabel)
  }

  private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 13))
        .foregroundStyle(ReframedColors.primaryText)
      Spacer()
      CustomToggle(isOn: isOn)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 4)
  }

  private func updateWindowBackgrounds() {
    let bg = ReframedColors.panelBackgroundNS
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

private struct MouseClickPreview: View {
  let color: Color
  let size: CGFloat

  @State private var clicks: [ClickRipple] = []
  @Environment(\.colorScheme) private var colorScheme

  struct ClickRipple: Identifiable {
    let id = UUID()
    let position: CGPoint
  }

  var body: some View {
    let _ = colorScheme
    ZStack {
      RoundedRectangle(cornerRadius: 6)
        .fill(ReframedColors.fieldBackground)

      if clicks.isEmpty {
        Text("Click to preview")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.dimLabel)
      }

      ForEach(clicks) { click in
        ExpandingCircle(color: color, diameter: size)
          .position(click.position)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .contentShape(Rectangle())
    .onTapGesture { location in
      let ripple = ClickRipple(position: location)
      clicks.append(ripple)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        clicks.removeAll { $0.id == ripple.id }
      }
    }
  }
}

private struct ExpandingCircle: View {
  let color: Color
  let diameter: CGFloat

  @State private var scale: CGFloat = 0.44
  @State private var opacity: Double = 1.0

  var body: some View {
    ZStack {
      Circle()
        .fill(color.opacity(0.3))
        .frame(width: diameter, height: diameter)
        .scaleEffect(scale)
        .opacity(opacity)
      Circle()
        .strokeBorder(color, lineWidth: 2)
        .frame(width: diameter, height: diameter)
        .scaleEffect(scale)
        .opacity(opacity)
    }
    .onAppear {
      withAnimation(.easeOut(duration: 0.4)) {
        scale = 1.0
        opacity = 0.0
      }
    }
  }
}

private struct ColorPresetRow: View {
  let name: String
  var subtitle: String? = nil
  let color: Color
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Circle()
          .fill(color)
          .frame(width: 18, height: 18)
        VStack(alignment: .leading, spacing: 1) {
          Text(name)
            .font(.system(size: 13))
            .foregroundStyle(ReframedColors.primaryText)
          if let subtitle {
            Text(subtitle)
              .font(.system(size: 11))
              .foregroundStyle(ReframedColors.dimLabel)
          }
        }
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ReframedColors.primaryText)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(ColorPresetRowHover())
  }
}

private struct ColorPresetRowHover: View {
  @State private var isHovered = false

  var body: some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(isHovered ? ReframedColors.hoverBackground : Color.clear)
      .padding(.horizontal, 4)
      .onHover { isHovered = $0 }
  }
}

private struct SettingsButtonStyle: ButtonStyle {
  @Environment(\.colorScheme) private var colorScheme

  func makeBody(configuration: Configuration) -> some View {
    let _ = colorScheme
    configuration.label
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(ReframedColors.primaryText)
      .padding(.horizontal, 14)
      .frame(height: 30)
      .background(configuration.isPressed ? ReframedColors.buttonPressed : ReframedColors.buttonBackground)
      .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}
