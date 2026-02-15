import AVFoundation
import SwiftUI

private enum SettingsTab: String, CaseIterable {
  case general = "General"
  case recording = "Recording"
  case devices = "Devices"
  case shortcuts = "Shortcuts"

  var icon: String {
    switch self {
    case .general: "gearshape"
    case .recording: "record.circle"
    case .devices: "mic.and.signal.meter"
    case .shortcuts: "keyboard"
    }
  }
}

struct SettingsView: View {
  var options: RecordingOptions?

  @State private var selectedTab: SettingsTab = .general
  @State var outputFolder: String = ConfigService.shared.outputFolder
  @State var cameraMaximumResolution: String = ConfigService.shared.cameraMaximumResolution
  @State var projectFolder: String = ConfigService.shared.projectFolder
  @State var appearance: String = ConfigService.shared.appearance
  @State var showMicPopover = false
  @State var showCameraPopover = false
  @Environment(\.colorScheme) private var colorScheme

  let fpsOptions = [24, 30, 40, 50, 60]

  var availableMicrophones: [AudioDevice] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    )
    return discovery.devices.map { AudioDevice(id: $0.uniqueID, name: $0.localizedName) }
  }

  var availableCameras: [CaptureDevice] {
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
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
          switch selectedTab {
          case .general:
            generalContent
          case .recording:
            recordingContent
          case .devices:
            devicesContent
          case .shortcuts:
            shortcutsContent
          }
        }
        .padding(Layout.settingsPadding)
      }
    }
    .frame(width: 600, height: 500)
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

  func devicePickerButton(label: String, isActive: Binding<Bool>) -> some View {
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

  func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(ReframedColors.dimLabel)
  }

  func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
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

  func updateWindowBackgrounds() {
    let bg = ReframedColors.panelBackgroundNS
    for window in NSApp.windows {
      if window.titlebarAppearsTransparent {
        window.backgroundColor = bg
      }
    }
  }

  func chooseProjectFolder() {
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

  func chooseOutputFolder() {
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

struct SettingsButtonStyle: ButtonStyle {
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
