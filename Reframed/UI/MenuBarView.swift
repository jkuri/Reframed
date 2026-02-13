import SwiftUI

struct RecentProject: Identifiable {
  let id = UUID()
  let url: URL
  let name: String
  let createdAt: Date
}

struct MenuBarView: View {
  let session: SessionState
  let onDismiss: () -> Void
  let onShowPermissions: () -> Void

  @State private var recentProjects: [RecentProject] = []
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(alignment: .leading, spacing: 0) {
      quickActions

      MenuBarDivider()

      recentProjectsSection

      MenuBarDivider()

      utilitySection
    }
    .padding(.vertical, 8)
    .frame(width: 320)
    .background(ReframedColors.panelBackground)
    .onAppear {
      loadRecentProjects()
    }
  }

  private var quickActions: some View {
    VStack(alignment: .leading, spacing: 6) {
      SectionHeader(title: "Quick Actions")

      MenuBarActionRow(icon: "record.circle", title: "New Recording", shortcut: "N") {
        onDismiss()
        if Permissions.allPermissionsGranted {
          session.showToolbar()
        } else {
          onShowPermissions()
        }
      }
      .padding(.horizontal, 12)
    }
  }

  private var recentProjectsSection: some View {
    VStack(alignment: .leading, spacing: 6) {
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
          .padding(.horizontal, 12)
        }

        MenuBarActionRow(icon: "folder", title: "Show All in Finder") {
          onDismiss()
          let path = (ConfigService.shared.projectFolder as NSString).expandingTildeInPath
          NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
        .padding(.horizontal, 12)
      }
    }
  }

  private var utilitySection: some View {
    VStack(alignment: .leading, spacing: 6) {
      MenuBarActionRow(icon: "info.circle", title: "About") {
        onDismiss()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
      }
      .padding(.horizontal, 12)

      MenuBarActionRow(icon: "power", title: "Quit", shortcut: "Q") {
        NSApp.terminate(nil)
      }
      .padding(.horizontal, 12)
    }
  }

  private func loadRecentProjects() {
    let path = (ConfigService.shared.projectFolder as NSString).expandingTildeInPath
    let folderURL = URL(fileURLWithPath: path)
    let fm = FileManager.default

    guard let contents = try? fm.contentsOfDirectory(
      at: folderURL,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
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
      projects.append(RecentProject(url: url, name: name, createdAt: metadata.createdAt))
    }

    recentProjects = projects
      .sorted { $0.createdAt > $1.createdAt }
      .prefix(5)
      .map { $0 }
  }
}

private struct ProjectRow: View {
  let project: RecentProject
  let action: () -> Void

  @State private var isHovered = false

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "film")
          .font(.system(size: 20))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 2) {
          Text(project.name)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)

          Text(Self.dateFormatter.string(from: project.createdAt))
            .font(.system(size: 11))
            .foregroundStyle(ReframedColors.tertiaryText)
        }

        Spacer()
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 7)
          .fill(isHovered ? ReframedColors.hoverBackground : Color.clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}

private struct MenuBarActionRow: View {
  let icon: String
  let title: String
  var shortcut: String? = nil
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundStyle(ReframedColors.secondaryText)
          .frame(width: 28)

        Text(title)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(ReframedColors.primaryText)

        Spacer()

        if let shortcut {
          Text("\u{2318}\(shortcut)")
            .font(.system(size: 12))
            .foregroundStyle(ReframedColors.tertiaryText)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 7)
          .fill(isHovered ? ReframedColors.hoverBackground : Color.clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}

private struct MenuBarDivider: View {
  var body: some View {
    Rectangle()
      .fill(ReframedColors.divider)
      .frame(height: 1)
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
  }
}
