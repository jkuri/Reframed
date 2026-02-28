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
  let fileSize: Int64?
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

  private let gridColumns = Array(
    repeating: GridItem(.flexible(), spacing: 6),
    count: 4
  )

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: 0) {
      SectionHeader(title: "Quick Actions")

      HoverEffectScope {
        LazyVGrid(columns: gridColumns, spacing: 6) {
          ActionGridItem(
            icon: "record.circle",
            title: "New",
            hoverId: "action.new"
          ) {
            onDismiss()
            if Permissions.allPermissionsGranted {
              session.showToolbar()
            } else {
              onShowPermissions()
            }
          }

          ActionGridItem(
            icon: "rectangle.inset.filled",
            title: "Display",
            hoverId: "action.display"
          ) {
            onDismiss()
            guard case .idle = session.state else { return }
            session.showToolbar()
            session.selectMode(.entireScreen)
          }

          ActionGridItem(
            icon: "macwindow",
            title: "Window",
            hoverId: "action.window"
          ) {
            onDismiss()
            guard case .idle = session.state else { return }
            session.showToolbar()
            session.selectMode(.selectedWindow)
          }

          ActionGridItem(
            icon: "rectangle.dashed",
            title: "Area",
            hoverId: "action.area"
          ) {
            onDismiss()
            guard case .idle = session.state else { return }
            session.showToolbar()
            session.selectMode(.selectedArea)
          }
        }
      }
      .disabled(isBusy)
      .padding(.horizontal, 10)

      MenuBarDivider()

      Text(totalProjectCount > 0 ? "Projects (\(totalProjectCount))" : "Projects")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(ReframedColors.secondaryText)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)

      if recentProjects.isEmpty {
        Text("No recent projects")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 12)
      } else {
        ScrollView {
          HoverEffectScope {
            LazyVStack(spacing: 0) {
              ForEach(recentProjects) { project in
                ProjectRow(project: project) {
                  onDismiss()
                  session.openProject(at: project.url)
                }
                .hoverEffect(id: "project.\(project.id)")
                .disabled(isBusy)
                .padding(.horizontal, 10)
              }
            }
          }
        }
        .frame(height: min(CGFloat(recentProjects.count) * 52, 52 * 6))
      }

      MenuBarDivider()

      HoverEffectScope {
        Button {
          onDismiss()
          let path = (ConfigService.shared.projectFolder as NSString).expandingTildeInPath
          NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } label: {
          Text("Open Projects Folder")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(id: "openFolder")
        .padding(.horizontal, 10)
      }

    }
    .padding(.vertical, 8)
    .frame(width: Layout.menuBarWidth)
    .background(ReframedColors.backgroundPopover)
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

      let bundleSize = Self.directorySize(url: url, fm: fm)

      projects.append(
        RecentProject(
          url: url,
          name: name,
          createdAt: metadata.createdAt,
          captureMode: metadata.captureMode,
          hasWebcam: metadata.hasWebcam || metadata.webcamSize != nil,
          hasSystemAudio: metadata.hasSystemAudio,
          hasMicrophoneAudio: metadata.hasMicrophoneAudio,
          duration: durationSeconds.flatMap { $0 > 0 ? $0 : nil },
          fileSize: bundleSize
        )
      )
    }

    let sorted = projects.sorted { $0.createdAt > $1.createdAt }
    totalProjectCount = sorted.count
    recentProjects = sorted
  }

  private static nonisolated func directorySize(url: URL, fm: FileManager) -> Int64? {
    guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
      return nil
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
        total += Int64(size)
      }
    }
    return total
  }
}

private struct ActionGridItem: View {
  let icon: String
  let title: String
  let hoverId: String
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    Button(action: action) {
      VStack(spacing: 3) {
        Image(systemName: icon)
          .font(.system(size: 18))
          .foregroundStyle(ReframedColors.primaryText)
          .frame(height: 22)

        Text(title)
          .font(.system(size: 10))
          .foregroundStyle(ReframedColors.secondaryText)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .hoverEffect(id: hoverId)
  }
}

private struct ProjectRow: View {
  let project: RecentProject
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: project.captureMode == .device ? "iphone" : "macbook")
          .font(.system(size: 18))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 2) {
          Text(project.name)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)

          HStack(spacing: 4) {
            Text(formatRelativeTime(project.createdAt))
              .font(.system(size: 11))
              .foregroundStyle(ReframedColors.secondaryText)

            if let duration = project.duration {
              Text("·")
                .font(.system(size: 11))
                .foregroundStyle(ReframedColors.secondaryText)

              Text(formatDuration(seconds: duration))
                .font(.system(size: 11))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if project.hasWebcam || project.hasSystemAudio || project.hasMicrophoneAudio {
              Text("·")
                .font(.system(size: 10))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if project.hasWebcam {
              Image(systemName: "web.camera")
                .font(.system(size: 11))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if project.hasSystemAudio {
              Image(systemName: "speaker.wave.2")
                .font(.system(size: 11))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if project.hasMicrophoneAudio {
              Image(systemName: "mic")
                .font(.system(size: 11))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if let fileSize = project.fileSize {
              Text("·")
                .font(.system(size: 11))
                .foregroundStyle(ReframedColors.secondaryText)

              Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                .font(.system(size: 11))
                .foregroundStyle(ReframedColors.secondaryText)
            }
          }
        }

        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
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
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
  }
}
