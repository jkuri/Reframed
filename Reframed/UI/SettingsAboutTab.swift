import SwiftUI

extension SettingsView {
  var aboutContent: some View {
    VStack(spacing: Layout.sectionSpacing) {
      appInfoSection
      updateSection
      linksSection
    }
    .frame(maxWidth: .infinity)
  }

  private var appInfoSection: some View {
    VStack(spacing: 12) {
      if let appIcon = NSImage(named: NSImage.applicationIconName) {
        Image(nsImage: appIcon)
          .resizable()
          .frame(width: 80, height: 80)
      }

      Text("Reframed")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(ReframedColors.primaryText)

      VStack(spacing: 4) {
        Text("Version \(UpdateChecker.currentVersion)")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)

        Text("Screen recording & editing for macOS")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.tertiaryText)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 8)
  }

  private var updateSection: some View {
    VStack(spacing: 12) {
      Button {
        Task { await checkForUpdates() }
      } label: {
        HStack(spacing: 6) {
          if updateCheckInProgress {
            ProgressView()
              .controlSize(.mini)
              .tint(ReframedColors.primaryText)
          }
          Text(updateCheckInProgress ? "Checking..." : "Check for Updates")
        }
      }
      .buttonStyle(OutlineButtonStyle(size: .small))
      .disabled(updateCheckInProgress)

      if let status = updateStatus {
        updateStatusView(status)
      }
    }
  }

  @ViewBuilder
  private func updateStatusView(_ status: UpdateStatus) -> some View {
    switch status {
    case .upToDate:
      HStack(spacing: 6) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .font(.system(size: 13))
        Text("You're up to date!")
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
      }

    case .available(let version, let url):
      VStack(spacing: 8) {
        HStack(spacing: 6) {
          Image(systemName: "arrow.up.circle.fill")
            .foregroundStyle(ReframedColors.primaryText)
            .font(.system(size: 13))
          Text("Version \(version) is available")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ReframedColors.primaryText)
        }

        Button("Download Update") {
          if let downloadURL = URL(string: url) {
            NSWorkspace.shared.open(downloadURL)
          }
        }
        .buttonStyle(OutlineButtonStyle(size: .small))
      }

    case .error(let message):
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
          .font(.system(size: 13))
        Text(message)
          .font(.system(size: 12))
          .foregroundStyle(ReframedColors.secondaryText)
      }
    }
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

      Text("Jan Kuri")
        .font(.system(size: 11))
        .foregroundStyle(ReframedColors.tertiaryText)
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
          .font(.system(size: 11))
        Text(title)
          .font(.system(size: 12))
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
