import SwiftUI

extension SettingsView {
  var aboutContent: some View {
    VStack(spacing: Layout.sectionSpacing) {
      appInfoSection
      updateSection
      changelogSection
      Spacer(minLength: 0)
      linksSection
    }
    .frame(maxWidth: .infinity)
    .containerRelativeFrame(.vertical) { height, _ in height - Layout.settingsPadding * 2 }
  }

  private var appInfoSection: some View {
    VStack(spacing: 12) {
      if let appIcon = NSImage(named: NSImage.applicationIconName) {
        Image(nsImage: appIcon)
          .resizable()
          .frame(width: 80, height: 80)
      }

      Text("Reframed")
        .font(.system(size: FontSize.xxxl, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)

      VStack(spacing: 4) {
        Text("Version \(UpdateChecker.currentVersion)")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.secondaryText)

        Text("Screen recording & editing for macOS")
          .font(.system(size: FontSize.xs))
          .foregroundStyle(ReframedColors.tertiaryText)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 8)
  }

  private var updateSection: some View {
    Button {
      if let delegate = NSApp.delegate as? AppDelegate {
        delegate.sparkleUpdater.checkForUpdates()
      }
    } label: {
      Text("Check for Updates")
    }
    .buttonStyle(OutlineButtonStyle(size: .small))
    .disabled(
      {
        guard let delegate = NSApp.delegate as? AppDelegate else { return true }
        return !delegate.sparkleUpdater.canCheckForUpdates
      }()
    )
  }

  private var changelogSection: some View {
    ChangelogView()
  }

  private var linksSection: some View {
    VStack(spacing: 8) {
      Divider()
        .background(ReframedColors.divider)

      HStack(spacing: 16) {
        linkButton("GitHub", icon: "arrow.up.right.square", url: "https://github.com/jkuri/Reframed")
        linkButton("Issues", icon: "ladybug", url: "https://github.com/jkuri/Reframed/issues")
        linkButton("Releases", icon: "shippingbox", url: "https://github.com/jkuri/Reframed/releases")
      }
      .padding(.top, 4)
    }
  }

  private func linkButton(_ title: String, icon: String, url: String) -> some View {
    Button {
      if let linkURL = URL(string: url) {
        NSWorkspace.shared.open(linkURL)
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: FontSize.xs))
        Text(title)
          .font(.system(size: FontSize.xs))
      }
      .foregroundStyle(ReframedColors.secondaryText)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if hovering {
        NSCursor.pointingHand.push()
      } else {
        NSCursor.pop()
      }
    }
  }
}

private struct ChangelogView: View {
  @State private var changelog: String?
  @State private var version: String?

  var body: some View {
    Group {
      if let version, let changelog, !changelog.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Latest Release — v\(version)")
            .font(.system(size: FontSize.xs, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)

          ScrollView {
            Text(changelog)
              .font(.system(size: FontSize.xxs))
              .foregroundStyle(ReframedColors.secondaryText)
              .frame(maxWidth: .infinity, alignment: .leading)
              .textSelection(.enabled)
          }
          .frame(maxHeight: 120)
        }
        .padding(10)
        .background(ReframedColors.muted)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      }
    }
    .task {
      if let result = await UpdateChecker.fetchLatestChangelog() {
        version = result.version
        changelog = result.changelog
      }
    }
  }
}
