import AVFoundation
import SwiftUI

private enum SettingsTab: String, CaseIterable {
  case general = "General"
  case recording = "Recording"
  case devices = "Devices"
  case shortcuts = "Shortcuts"
  case about = "About"

}

struct SettingsView: View {
  var options: RecordingOptions?

  @State private var selectedTab: SettingsTab = .general
  @State var outputFolder: String = ConfigService.shared.outputFolder
  @State var cameraMaximumResolution: String = ConfigService.shared.cameraMaximumResolution
  @State var projectFolder: String = ConfigService.shared.projectFolder
  @State var appearance: String = ConfigService.shared.appearance
  @State var updateCheckInProgress = false
  @State var updateStatus: UpdateStatus? = nil
  @Environment(\.colorScheme) private var colorScheme

  let fpsOptions = [24, 30, 40, 50, 60]

  var availableMicrophones: [AudioDevice] {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.microphone],
      mediaType: .audio,
      position: .unspecified
    )
    return discovery.devices
      .filter { !$0.uniqueID.contains("CADefaultDeviceAggregate") }
      .map { AudioDevice(id: $0.uniqueID, name: $0.localizedName) }
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
        VStack(alignment: .leading, spacing: 18) {
          switch selectedTab {
          case .general:
            generalContent
          case .recording:
            recordingContent
          case .devices:
            devicesContent
          case .shortcuts:
            shortcutsContent
          case .about:
            aboutContent
          }
        }
        .padding(Layout.settingsPadding)
      }
    }
    .frame(width: 600, height: 460)
    .background(ReframedColors.backgroundPopover)
  }

  private var tabBar: some View {
    HoverEffectScope {
      HStack(spacing: 4) {
        ForEach(SettingsTab.allCases, id: \.self) { tab in
          Button {
            selectedTab = tab
          } label: {
            Text(tab.rawValue)
              .font(.system(size: FontSize.xs, weight: .medium))
              .foregroundStyle(selectedTab == tab ? ReframedColors.primaryText : ReframedColors.secondaryText)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .background(selectedTab == tab ? ReframedColors.muted : Color.clear)
              .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .hoverEffect(id: "settings.tab.\(tab.rawValue)")
        }
      }
      .padding(.horizontal, Layout.settingsPadding)
      .padding(.vertical, 12)
    }
  }

  func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.system(size: FontSize.xs, weight: .medium))
        .foregroundStyle(ReframedColors.primaryText)
      content()
    }
  }

  func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
    HStack {
      Text(title)
        .font(.system(size: FontSize.xs, weight: .medium))
        .foregroundStyle(ReframedColors.primaryText)
      Spacer()
      CustomToggle(isOn: isOn)
    }
  }

  func updateWindowBackgrounds() {
    let bg = ReframedColors.backgroundNS
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

  func checkForUpdates() async {
    updateCheckInProgress = true
    updateStatus = nil
    updateStatus = await UpdateChecker.checkForUpdates()
    updateCheckInProgress = false
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
