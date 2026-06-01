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

struct ActionGridItem: View {
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
          .font(.system(size: FontSize.lg))
          .foregroundStyle(ReframedColors.primaryText)
          .frame(height: 22)

        Text(LocalizedStringKey(title))
          .font(.system(size: FontSize.xxs, weight: .semibold))
          .foregroundStyle(ReframedColors.primaryText)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .clipShape(RoundedRectangle(cornerRadius: Radius.md))
      .contentShape(Rectangle())
    }
    .buttonStyle(PlainCustomButtonStyle())
    .hoverEffect(id: hoverId)
  }
}

struct PermissionsPrompt: View {
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    VStack(spacing: 8) {
      Image(systemName: "lock.shield")
        .font(.system(size: FontSize.xl))
        .foregroundStyle(ReframedColors.secondaryText)

      Text("Reframed needs Screen Recording and Accessibility permissions to work.")
        .font(.system(size: FontSize.xxs))
        .foregroundStyle(ReframedColors.secondaryText)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Button(action: action) {
        Text("Grant Permissions")
          .font(.system(size: FontSize.xxs, weight: .medium))
      }
      .buttonStyle(OutlineButtonStyle())
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 10)
    .padding(.vertical, 10)
  }
}

struct ProjectRow: View {
  let project: RecentProject
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let _ = colorScheme
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: project.captureMode == .device ? "iphone" : "macbook")
          .font(.system(size: FontSize.lg))
          .foregroundStyle(ReframedColors.primaryText)
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 2) {
          Text(project.name)
            .font(.system(size: FontSize.xs, weight: .semibold))
            .foregroundStyle(ReframedColors.primaryText)
            .lineLimit(1)

          HStack(spacing: 4) {
            Text(formatRelativeTime(project.createdAt))
              .font(.system(size: FontSize.xxs, weight: .medium))
              .foregroundStyle(ReframedColors.secondaryText)

            if let duration = project.duration {
              Text("·")
                .font(.system(size: FontSize.xxs, weight: .medium))
                .foregroundStyle(ReframedColors.secondaryText)

              Text(formatDuration(seconds: duration))
                .font(.system(size: FontSize.xxs, weight: .medium))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if let fileSize = project.fileSize {
              Text("·")
                .font(.system(size: FontSize.xxs, weight: .medium))
                .foregroundStyle(ReframedColors.secondaryText)

              Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                .font(.system(size: FontSize.xxs, weight: .medium))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if project.hasWebcam || project.hasSystemAudio || project.hasMicrophoneAudio {
              Text("·")
                .font(.system(size: FontSize.xxs, weight: .medium))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if project.hasWebcam {
              Image(systemName: "web.camera")
                .font(.system(size: FontSize.xxs, weight: .medium))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if project.hasSystemAudio {
              Image(systemName: "speaker.wave.2")
                .font(.system(size: FontSize.xxs, weight: .medium))
                .foregroundStyle(ReframedColors.secondaryText)
            }

            if project.hasMicrophoneAudio {
              Image(systemName: "mic")
                .font(.system(size: FontSize.xxs, weight: .medium))
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
    .buttonStyle(PlainCustomButtonStyle())
  }
}

struct MenuBarDivider: View {
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
