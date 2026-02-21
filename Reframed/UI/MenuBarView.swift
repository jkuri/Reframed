import AVFoundation
import SwiftUI

struct RecentProject: Identifiable {
  let id = UUID()
  let url: URL
  let name: String
  let createdAt: Date
  let captureMode: CaptureMode?
  let hasWebcam: Bool
  let hasSystemAudio: Bool
  let hasMicrophoneAudio: Bool
  let duration: Int?
}

struct MenuBarView: View {
  let session: SessionState
  let onDismiss: () -> Void
  let onShowPermissions: () -> Void

  @State private var recentProjects: [RecentProject] = []
  @State private var totalProjectCount: Int = 0
  @Environment(\.colorScheme) private var colorScheme

  private var isBusy: Bool {
    if case .idle = session.state { return false }
    if case .editing = session.state { return false }
    return true
  }

  var body: some View {
    let _ = colorScheme
    HoverEffectScope {
      VStack(alignment: .leading, spacing: 0) {
        SectionHeader(title: "Quick Actions")

        MenuBarActionRow(icon: "record.circle", title: "New Recording", shortcut: "N") {
          onDismiss()
          if Permissions.allPermissionsGranted {
            session.showToolbar()
          } else {
            onShowPermissions()
          }
        }
        .hoverEffect(id: "menu.newRecording")
        .disabled(isBusy)
        .padding(.horizontal, 12)

        MenuBarActionRow(
          icon: "rectangle.dashed",
          title: "Display Mode",
          shortcut: ConfigService.shared.shortcut(for: .switchToDisplay).displayString
        ) {
          onDismiss()
          guard case .idle = session.state else { return }
          session.showToolbar()
          session.selectMode(.entireScreen)
        }
        .hoverEffect(id: "menu.displayMode")
        .disabled(isBusy)
        .padding(.horizontal, 12)

        MenuBarActionRow(
          icon: "macwindow",
          title: "Window Mode",
          shortcut: ConfigService.shared.shortcut(for: .switchToWindow).displayString
        ) {
          onDismiss()
          guard case .idle = session.state else { return }
          session.showToolbar()
          session.selectMode(.selectedWindow)
        }
        .hoverEffect(id: "menu.windowMode")
        .disabled(isBusy)
        .padding(.horizontal, 12)

        MenuBarActionRow(
          icon: "rectangle.dashed.badge.record",
          title: "Area Mode",
          shortcut: ConfigService.shared.shortcut(for: .switchToArea).displayString
        ) {
          onDismiss()
          guard case .idle = session.state else { return }
          session.showToolbar()
          session.selectMode(.selectedArea)
        }
        .hoverEffect(id: "menu.areaMode")
        .disabled(isBusy)
        .padding(.horizontal, 12)

        MenuBarDivider()

        SectionHeader(title: "Recent Projects")

        if recentProjects.isEmpty {
          Text("No recent projects")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        } else {
          ForEach(recentProjects) { project in
            ProjectRow(project: project) {
              onDismiss()
              session.openProject(at: project.url)
            }
            .hoverEffect(id: "menu.project.\(project.id)")
            .disabled(isBusy)
            .padding(.horizontal, 12)
          }

          MenuBarDivider()

          MenuBarActionRow(
            icon: "folder",
            title: "Open Projects Folder",
            subtitle: "\(totalProjectCount) project\(totalProjectCount == 1 ? "" : "s")"
          ) {
            onDismiss()
            let path = (ConfigService.shared.projectFolder as NSString).expandingTildeInPath
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
          }
          .hoverEffect(id: "menu.openProjects")
          .disabled(isBusy)
          .padding(.horizontal, 12)
        }

        MenuBarDivider()

        MenuBarActionRow(icon: "info.circle", title: "About") {
          onDismiss()
          NSApp.activate(ignoringOtherApps: true)
          NSApp.orderFrontStandardAboutPanel(nil)
        }
        .hoverEffect(id: "menu.about")
        .padding(.horizontal, 12)

        MenuBarActionRow(icon: "power", title: "Quit", shortcut: "Q") {
          NSApp.terminate(nil)
        }
        .hoverEffect(id: "menu.quit")
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
      }
      .padding(.vertical, 8)
      .frame(width: 320)
    }
    .background(ReframedColors.background)
    .task {
      await loadRecentProjects()
    }
  }

  private func loadRecentProjects() async {
    let path = (ConfigService.shared.projectFolder as NSString).expandingTildeInPath
    let folderURL = URL(fileURLWithPath: path)
    let fm = FileManager.default

    guard
      let contents = try? fm.contentsOfDirectory(
        at: folderURL,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
      )
    else {
      recentProjects = []
      return
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    var projects: [RecentProject] = []
    for url in contents where url.pathExtension == "frm" {
      let metadataURL = url.appendingPathComponent("project.json")
      guard let data = try? Data(contentsOf: metadataURL),
        let metadata = try? decoder.decode(ProjectMetadata.self, from: data)
      else { continue }

      let name = metadata.name ?? url.deletingPathExtension().lastPathComponent
      let screenURL = url.appendingPathComponent("screen.mp4")
      let asset = AVURLAsset(url: screenURL)
      let duration = try? await asset.load(.duration)
      let durationSeconds = duration.map { Int(CMTimeGetSeconds($0)) }

      projects.append(
        RecentProject(
          url: url,
          name: name,
          createdAt: metadata.createdAt,
          captureMode: metadata.captureMode,
          hasWebcam: metadata.hasWebcam || metadata.webcamSize != nil,
          hasSystemAudio: metadata.hasSystemAudio,
          hasMicrophoneAudio: metadata.hasMicrophoneAudio,
          duration: durationSeconds.flatMap { $0 > 0 ? $0 : nil }
        )
      )
    }

    let sorted = projects.sorted { $0.createdAt > $1.createdAt }
    totalProjectCount = sorted.count
    recentProjects = sorted.prefix(5).map { $0 }
  }
}

private struct ProjectRow: View {
  let project: RecentProject
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  private var sourceIcon: String {
    switch project.captureMode {
    case .device:
      return "iphone"
    default:
      return "macbook"
    }
  }

  var body: some View {
    let _ = colorScheme
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: sourceIcon)
          .font(.system(size: 18))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(project.name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)

          HStack(spacing: 4) {
            Text(Self.dateFormatter.string(from: project.createdAt))
              .font(.system(size: 10))
              .foregroundStyle(ReframedColors.tertiaryText)

            if let duration = project.duration {
              Text("·")
                .font(.system(size: 10))
                .foregroundStyle(ReframedColors.tertiaryText)

              Text(formatDuration(seconds: duration))
                .font(.system(size: 10))
                .foregroundStyle(ReframedColors.tertiaryText)
            }

            if project.hasWebcam || project.hasSystemAudio || project.hasMicrophoneAudio {
              Text("·")
                .font(.system(size: 10))
                .foregroundStyle(ReframedColors.tertiaryText)
            }

            if project.hasWebcam {
              Image(systemName: "web.camera")
                .font(.system(size: 9))
                .foregroundStyle(ReframedColors.tertiaryText)
            }

            if project.hasSystemAudio {
              Image(systemName: "speaker.wave.2")
                .font(.system(size: 9))
                .foregroundStyle(ReframedColors.tertiaryText)
            }

            if project.hasMicrophoneAudio {
              Image(systemName: "mic")
                .font(.system(size: 9))
                .foregroundStyle(ReframedColors.tertiaryText)
            }
          }
        }

        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct MenuBarActionRow: View {
  let icon: String
  let title: String
  var subtitle: String? = nil
  var shortcut: String? = nil
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  private var shortcutLabel: String? {
    guard let shortcut else { return nil }
    if shortcut.count == 1 {
      return "\u{2318}\(shortcut)"
    }
    return shortcut
  }

  var body: some View {
    let _ = colorScheme
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 18))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 24)

        if let subtitle {
          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(ReframedColors.primaryText)

            Text(subtitle)
              .font(.system(size: 10))
              .foregroundStyle(ReframedColors.tertiaryText)
          }
        } else {
          Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
        }

        Spacer()

        if let shortcutLabel {
          Text(shortcutLabel)
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.tertiaryText)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct MenuBarDivider: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    Rectangle()
      .fill(ReframedColors.divider)
      .frame(height: 1)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
  }
}
